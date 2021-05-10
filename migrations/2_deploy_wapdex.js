const WapFactory = artifacts.require("WapFactory");
const feeToSetter = '0x27619960d55b6aFB7E3cef6Ede8D9d8c6fE9DFE6';
const wap_token_address = '0xDFb3F23227D22b834497c6a50C3984bFa7b19032';

const WapRouter = artifacts.require("WapRouter");
const wht = '0x7af326b6351c8a9b8fb8cd205cbe11d4ac5fa836';  // 主 0x5545153ccfca01fbd7dd11c0b23ba694d9509a6f  测试 0x7aF326B6351C8A9b8fb8CD205CBe11d4Ac5FA836
const factory_address = '0x7Ac6518aca6CA82b208412d6e9E41E07a44989a6';

const HecoPool = artifacts.require("HecoPool");
const SwapMining = artifacts.require("SwapMining");
const Oracle = artifacts.require("Oracle");
const oracle_address = '0x59EcE50abcaacC4116Ec09e4302A458a1Ca3ECC0';
const router_address = '0xebdb4f6DCCFdf52c37a096fb9eEb759938ca8205';
const usdt_address = '0x0E90bf7Ab12FF8f05777359aEA0d161d72E73FeE';

const num = 100e18;
const wapPerBlock = "0x" + num.toString(16);

const TeamTimeLock = artifacts.require("TeamTimeLock");
const Ranklist = artifacts.require("Ranklist");
const waptoken = '0xDFb3F23227D22b834497c6a50C3984bFa7b19032';
// const Testcon = artifacts.require("Testcon");

module.exports = function (deployer) {
    // deployer.deploy(Testcon);
    // deployer.deploy(WapFactory, feeToSetter);
    // deployer.deploy(WapRouter, factory_address, wht);
    // deployer.deploy(HecoPool, wap_token_address, wapPerBlock, 4036089);
    // deployer.deploy(Oracle, factory_address);
    // deployer.deploy(SwapMining, wap_token_address, factory_address, oracle_address, router_address, usdt_address, wapPerBlock, 0);
    // deployer.deploy(Ranklist, waptoken, factory_address, router_address);
};
