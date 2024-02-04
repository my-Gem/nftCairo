// SPDX-License-Identifier: MIT

use starknet::ContractAddress;
// Factory合约的接口
// #[starknet::interface] 可理解成solidity的接口或java的注解,只要添加这个注解系统就会自动给接口产生两个调度程序IFactoryDispatcher与IFactoryDispatcherTrait,这两个文件用于合约调用.
#[starknet::interface]
trait IFactoryV3<TState> {
    fn createNft(
        ref self: TState,
        _caller: ContractAddress,
        _erc721Hash: felt252,
        _salt: felt252,
        _blindBoxOpened: felt252,
        _total: felt252,
        _mintMaxAmount: felt252,
        _airDrop: felt252,
        _switch: felt252,
        _publicMintPrice: felt252,
        _blindTokenURI: felt252,
        _name: felt252,
        _symbol: felt252
    ) -> ContractAddress;
}

// mod关键字即声明合约, #[starknet::contract]可理解成java的注解,必须写上
#[starknet::contract]
mod Router {
   
    use integer::u256;
    use integer::u256_from_felt252;
    use openzeppelin::access::ownable::Ownable;
    use openzeppelin::token::erc20::interface::ERC20CamelABI;
    use openzeppelin::token::erc20::interface::ERC20CamelABIDispatcher;
    use openzeppelin::token::erc20::interface::ERC20CamelABIDispatcherTrait;
    use super::IFactoryV3Dispatcher;
    use super::IFactoryV3DispatcherTrait;
    use starknet::{ContractAddress, get_caller_address};

    //  #[storage] 可理解成solidity中用于存储状态变量的插槽,如果starknet contract中没有状态变量, #[storage],struct 也必须要写上
    #[storage]
    struct Storage {
        FactoryV3: ContractAddress,
        IsFunParms: u8,
    }

    // 可理解成solidity的event
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        IsFun: IsFun,
        Nft: Nft
    }

    #[derive(Drop, starknet::Event)]
    struct IsFun {
        #[key]
        _isFun: u8
    }

    #[derive(Drop, starknet::Event)]
    struct Nft {
        #[key]
        _deployer: ContractAddress,
        #[key]
        _nftAddress: ContractAddress
    }

    // 构造方法功能是初始化合约可理解成solidity的constructor方法
    #[constructor]
    fn constructor(ref self: ContractState, _factory: ContractAddress, _manager: ContractAddress) {
        let mut unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref unsafe_state_ownable, _manager);
        self.FactoryV3.write(_factory);
    }


    // 方法功能是更改管理员
    #[external(v0)]
    fn changeManger(ref self: ContractState, _newmanager: ContractAddress) {
        let mut unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        Ownable::OwnableCamelOnlyImpl::transferOwnership(ref unsafe_state_ownable, _newmanager);
    }

    // 方法功能是外部设置NFT平台是否启动或停止
    // [external(v0)] 可理解成solidity的external
    #[external(v0)]
    fn changeNftStatus(ref self: ContractState, _isFun: u8) {
        let unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        self.IsFunParms.write(_isFun);
        self.emit(IsFun { _isFun });
    }

    // 方法功能是查询NFT平台是否已启动或停止
    #[external(v0)]
    fn checkNftStatus(self: @ContractState) -> u8 {
        self.IsFunParms.read()
    }


    // 方法功能是创建NFT,可理解成部署NFT合约
    // _erc721Hash即erc721的类哈希
    // _salt即合约部署的盐值
    // _blindBoxOpened即盲盒是否开启
    // _mintMaxAmount即Nft铸造限制的数量
    // _airDrop即管理员可以赠送的Nft数量
    // _switch即Nft项目是否开始还是结束
    // _publicMintPrice即公开mint的价格
    // _blindTokenURI即盲盒的Url
    // _name即NFT名称
    // _symbol即NFT简称
    #[external(v0)]
    fn createNft(
        ref self: ContractState,
        _erc721Hash: felt252,
        _salt: felt252,
        _blindBoxOpened: felt252,
        _total: felt252,
        _mintMaxAmount: felt252,
        _airDrop: felt252,
        _switch: felt252,
        _publicMintPrice: felt252,
        _blindTokenURI: felt252,
        _name: felt252,
        _symbol: felt252
    ) {
        assert(self.IsFunParms.read() > 1,'Nft has not started yet'); 
        // _caller即调用者地址
        let _caller = get_caller_address();
        // 平台收取0.0001 eth
        let amount: u256 = u256_from_felt252(100000000000000);
        // eth即eth合约地址,主网/测试网都是同一合约地址,在starknet中eth是以erc20 token的形式存在,可理解成dex常用的weth token
        let eth: ContractAddress = 0x49D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        // eth_erc20_token即eth合约对象
        let mut eth_erc20_token = ERC20CamelABIDispatcher { contract_address: eth };
        let mut unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        let _manager: ContractAddress = Ownable::OwnableImpl::owner(@unsafe_state_ownable);
        eth_erc20_token.transferFrom(_caller, _manager, amount);
        // 调用factory合约去创建NFT
        let nft: ContractAddress = IFactoryV3Dispatcher { contract_address: self.FactoryV3.read() }
        .createNft(
                _caller,
                _erc721Hash,
                _salt,
                _blindBoxOpened,
                _total,
                _mintMaxAmount,
                _airDrop,
                _switch,
                _publicMintPrice,
                _blindTokenURI,
                _name,
                _symbol
            );
        // 通过事件存储nft合约与部署者地址,再通过链外解析交易收据拿到部署者地址与NFT合约地址,这步骤等同于solidity中的emit触发事件用于存储日志
        self.emit(Nft { _deployer: _caller, _nftAddress: nft });
    }


}
