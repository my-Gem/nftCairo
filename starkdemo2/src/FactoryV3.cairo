// SPDX-License-Identifier: MIT

#[starknet::contract]
mod FactoryV3 {
   
    use integer::u64_to_felt252;
    use integer::u64_try_from_felt252;
    use starknet::get_block_timestamp;
    use starknet::syscalls::deploy_syscall;
    use result::ResultTrait;
    use array::ArrayTrait;
    use array::SpanTrait;
    use starknet::{ContractAddress, get_caller_address, contract_address_to_felt252};
    use openzeppelin::access::ownable::Ownable;
    
    #[storage]
    struct Storage {
        ReentrancyGuard_entered: bool,
        Router: ContractAddress
    }

    mod Errors {
        const REENTRANT_CALL: felt252 = 'ReentrancyGuard: reentrant call';
    }

    #[constructor]
    fn constructor(ref self: ContractState, _manager: ContractAddress) {  
        let mut unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::initializer(ref unsafe_state_ownable, _manager); 
    }

    #[external(v0)]
    fn changeParams(ref self: ContractState, _router: ContractAddress) {
        let unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        self.Router.write(_router);
    }

    // 私有方法可理解成solidity的internal
    #[generate_trait]
    fn create(
        ref self: ContractState,
        _owner: ContractAddress,
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
    ) -> ContractAddress {
        let owner: felt252 = contract_address_to_felt252(_owner);
        // 盐值
        let salt: felt252 = u64_to_felt252 (get_block_timestamp() +  u64_try_from_felt252(_salt).unwrap());
        let mut calldata = array![owner, _blindBoxOpened, _total, _mintMaxAmount, _airDrop, _switch, _publicMintPrice, _blindTokenURI, _name, _symbol];
        let (nftAddress, _) = deploy_syscall(_erc721Hash.try_into().unwrap(), _salt, calldata.span(), true).unwrap();
        nftAddress
    }

    #[external(v0)]
    fn createNft(
        ref self: ContractState,
        _owner: ContractAddress,
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
    ) -> ContractAddress {
        assert(self.Router.read() == get_caller_address(), 'Only Router');
        assert(!self.ReentrancyGuard_entered.read(), Errors::REENTRANT_CALL);
        self.ReentrancyGuard_entered.write(true);
        // 部署Nft合约并返回nft的合约地址,calldata即Nft合约构造方法的参数
        let nft = create(
            ref self,
            _owner,
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
        self.ReentrancyGuard_entered.write(false);
        nft
    }

}