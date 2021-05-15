// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "../interface/IERC20.sol";
import "../library/SafeMath.sol";
import "../interface/IWapFactory.sol";
import "../interface/IWapPair.sol";

interface IWap is IERC20 {
    function mint(address to, uint256 amount) external returns (bool);
}

contract Ranklist is Ownable {
    struct UserInfo {
        uint256 total_amount;  // 累计奖励wap数量
        uint256 balance_amount;  // 当前用户剩余可提现奖励wap数量
    }

    struct UserRank {
        address account;  
        uint256 price;  
    }

    using SafeMath for uint256;
    // Add the library methods
    using EnumerableSet for EnumerableSet.AddressSet;
    // 交易对集合
    EnumerableSet.AddressSet private pairset;
    // 对应交易对集合的计价地址
    mapping(address => address) public pairset_price;
    // 交易对前10集合，无序的
    mapping(address => EnumerableSet.AddressSet) private pair_rankset_index;
    // 交易对前10集合及其价格
    mapping(address => mapping(address => uint256)) public pair_rankset;
    // 用户数据
    mapping(address => UserInfo) public userinfo;

    uint limit_usdt = 0;  // 用户兑换相应代币，换算成USDT，可以上榜的最少USDT数量，18个小数位
    address public router;
    IWapFactory public factory;
    IWap public wap;
    uint public last_time_awards;  // 最近一次奖励时间
    uint public reward_per_hour;
    uint public max_num = 10;  // 最大排行榜数量
    uint public reward_per_hour_user;
    // 控制提现和排行榜功能
    bool public paused = false;

    constructor (
        IWap _wap,
        IWapFactory _factory,
        address _router
    ) public {
        wap = _wap;
        factory = _factory;
        router = _router;
    }

    function setLimitUSDT(uint _limit_usdt) external onlyOwner {
        limit_usdt = _limit_usdt;
    }

    function setPause() external onlyOwner {
        paused = !paused;
    }

    modifier notPause() {
        require(paused == false, "Service has been suspended");
        _;
    }

    function userRankDatas(address pair) view external returns(UserRank[10] memory datas) {
        require(pair != address(0), "Ranklist: zero address");

        EnumerableSet.AddressSet storage set = pair_rankset_index[pair];
        mapping(address => uint256) storage set2 = pair_rankset[pair];

        for (uint256 i = 0;  i < EnumerableSet.length(set) && i < 10; i++) {
            address t1 = EnumerableSet.at(set, i);
            UserRank memory u = datas[i];
            u.account = t1;
            u.price = set2[t1];
        }
    }

    /**
     * _reward_per_hour: 设置每小时产生的wap数量
     * _reward_per_hour_user: 用户每小时获取的wap数量
     */
    function setRewardPerHourAndUserReward(uint _reward_per_hour, uint _reward_per_hour_user) external onlyOwner {
        require(_reward_per_hour_user <= _reward_per_hour, "Ranklist: _reward_per_hour_user too large");
        reward_per_hour = _reward_per_hour;
        reward_per_hour_user = _reward_per_hour_user;
    }

    /**
     * 获取用户wap奖励，当合约暂停时停止获取奖励
     */
    function getReward() external notPause {
        if (userinfo[msg.sender].balance_amount > 0) {
            uint256 balance = userinfo[msg.sender].balance_amount;
            require(balance <= wap.balanceOf(address(this)), "Ranklist: INSUFFICIENT_WAP_BALANCE");

            userinfo[msg.sender].balance_amount = 0;
            wap.transfer(msg.sender, balance);
        }
    }

    /**
     * 添加可获取奖励的交易对
     * tokenA: A代币地址
     * tokenB: B代币地址
     * price_addr: 用于计价的代币地址（A或者B）
     */
    function addRewardPair(address tokenA, address tokenB, address price_addr) external onlyOwner {
        require(tokenA != address(0), "Ranklist: zero address");
        require(tokenB != address(0), "Ranklist: zero address");
        require(price_addr != address(0), "Ranklist: zero address");
        if (EnumerableSet.length(pairset) >= max_num) {
            return;
        }

        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), "Ranklist: no pair");
        if (!EnumerableSet.contains(pairset, pair)) {
            EnumerableSet.add(pairset, pair);
        }
        pairset_price[pair] = price_addr;
    }

    /**
     * 删除可获取奖励的交易对
     * tokenA: A代币地址
     * tokenB: B代币地址
     */
    function removeRewardPair(address tokenA, address tokenB) external onlyOwner {
        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), "Ranklist: no pair");
        if (!EnumerableSet.contains(pairset, pair)) {
            return;
        }

        EnumerableSet.remove(pairset, pair); // 仅删除引用
    }

    /**
     * 更新用户兑换过程所处价格的前10位置
     */
    function swap(address account, address input, uint256 amountIn, address output, uint256 amountOut) external onlyRouter {
        // 当合约暂停，则不再产生新的奖励
        if (paused)
            return;

        require(account != address(0), "Ranklist: taker swap account is the zero address");
        require(input != address(0), "Ranklist: taker swap input is the zero address");
        require(output != address(0), "Ranklist: taker swap output is the zero address");

        // 判断此交易对是否在奖励集合中
        address pair = factory.getPair(input, output);
        if (!EnumerableSet.contains(pairset, pair)) {
            return;
        }

        // 如果不是购买指定代币，则退出
        if (output != pairset_price[pair]) {
            return;
        }

        // 判断是否满足最少USDT数量
        if (amountIn < limit_usdt) {
            return;
        }

        // 获取当前交易对价格
        uint256 price = amountIn.mul(1e18).div(amountOut);  // 扩展18位小数

        EnumerableSet.AddressSet storage set = pair_rankset_index[pair];
        mapping(address => uint256) storage set2 = pair_rankset[pair];

        // 第一次兑换时直接设置最后一次分配奖励时间
        if (last_time_awards == 0) {
            last_time_awards = block.timestamp;
        }
        
        // 如果离上一次分配奖励时间超过1小时，计算超过的小时数
        uint one_hour_seconds = 3600;  // 默认3600
        uint mint_hours = block.timestamp.sub(last_time_awards).div(one_hour_seconds);
        if (mint_hours >= 1) {
            // 计算当前用于分配奖励的wap数量，并转账到本合约
            uint mint_num = mint_hours.mul(reward_per_hour);
            if (mint_num > 0) {
                wap.mint(address(this), mint_num);
            }

            // 对所有交易对前10用户分配相应奖励，并清空交易对排名
            for (uint j = 0; j < EnumerableSet.length(pairset); j++) {
                address pair_addr = EnumerableSet.at(pairset, j);
                EnumerableSet.AddressSet storage setj = pair_rankset_index[pair_addr];

                uint length = EnumerableSet.length(setj);
                for (uint256 i = 0;  i < length && i < max_num; i++) {
                    address t1 = EnumerableSet.at(setj, i);
                    UserInfo storage u = userinfo[t1];
                    u.total_amount = u.total_amount.add(mint_hours.mul(reward_per_hour_user));
                    u.balance_amount = u.balance_amount.add(mint_hours.mul(reward_per_hour_user));
                }

                // 依次删除所有记录
                for (uint i = 0; i < length; i++) {
                    address t1 = EnumerableSet.at(setj, 0);
                    EnumerableSet.remove(setj, t1);
                }
            }
            last_time_awards = block.timestamp;
        }

        // 判断用户是否处于已经存在，如果已存在，则保留价格较高的价格
        if (EnumerableSet.contains(set, account)) {
            if (price > set2[account]) {
                set2[account] = price;
            }
        } else {
            // 如果前10的名额不足，则直接添加
            if (EnumerableSet.length(set) != max_num) {
                EnumerableSet.add(set, account);
                set2[account] = price;
            } else {
                // 查找前10中最小价格的用户
                address min_u1 = EnumerableSet.at(set, 0);
                uint256 min_p1 = set2[min_u1];
                for (uint256 i = 1; i < EnumerableSet.length(set) && i < max_num; i++) {
                    address t1 = EnumerableSet.at(set, i);
                    
                    if (set2[t1] < min_p1) {
                        min_p1 = set2[t1];
                        min_u1 = t1;
                    }
                }

                // 比较最小价格用户是否小于当前用户价格，如果是则替换最小价格用户
                if (price > min_p1) {
                    EnumerableSet.remove(set, min_u1);
                    EnumerableSet.add(set, account);
                    set2[account] = price;
                }
            }
        }
    }

    modifier onlyRouter() {
        require(msg.sender == router, "Ranklist: caller is not the router");
        _;
    }
}
