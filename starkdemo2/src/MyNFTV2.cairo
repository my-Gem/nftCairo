// SPDX-License-Identifier: MIT

#[starknet::contract]
mod MyNftV2 {
    
    use integer::u256;
    use integer::u256_from_felt252;
    use array::ArrayTrait;
    // 导入 Into 特质
    use traits::Into;
    // 导入 TryInto 特质
    use traits::TryInto;
    use option::OptionTrait;
    use openzeppelin::token::erc20::interface::ERC20CamelABI;
    use openzeppelin::token::erc20::interface::ERC20CamelABIDispatcher;
    use openzeppelin::token::erc20::interface::ERC20CamelABIDispatcherTrait;
    use openzeppelin::token::erc721::ERC721;
    use openzeppelin::access::ownable::Ownable;
    use openzeppelin::upgrades::upgradeable::Upgradeable;
    use starknet::{ClassHash, ContractAddress, get_caller_address, ContractAddressIntoFelt252, contract_address_to_felt252};

    #[storage]
    struct Storage {
        ReentrancyGuard_entered: bool,
        TokenId: u256,
        CurrentIndex: u256,
        WhiteListSwitch: u256,
        PublicMintSwitch: u256,
        BlindBoxOpened: u256,
        TotalSupply: felt252,
        MintMaxAmount: felt252,
        AirDrop: felt252,
        BlindTokenURI: felt252,
        PublicMintPrice: felt252,
        MintLimited: LegacyMap<(ContractAddress, u256), bool>,
        WhiteListUser: LegacyMap<ContractAddress, bool>
    }

    mod Errors {
        const REENTRANT_CALL: felt252 = 'ReentrancyGuard: reentrant call';
        const INVALID_ACCOUNT: felt252 = 'MyNftV2: invalid account';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        _owner: felt252,
        _blindBoxOpened: felt252,
        _total: felt252,
        _mintMaxAmount: felt252,
        _airDrop: felt252,
        _whiteListSwitch: felt252,
        _publicMintPrice: felt252,
        _blindTokenURI: felt252,
        _name: felt252,
        _symbol: felt252
    ) {
        self.BlindBoxOpened.write(u256_from_felt252(_blindBoxOpened));
        self.BlindTokenURI.write(_blindTokenURI);
        self.MintMaxAmount.write(_mintMaxAmount);
        self.TotalSupply.write(_total);
        self.AirDrop.write(_airDrop);
        self.WhiteListSwitch.write(u256_from_felt252(_whiteListSwitch));
        self.PublicMintSwitch.write(1);
        self.PublicMintPrice.write(_publicMintPrice);
        let mut unsafe_state_erc721 = ERC721::unsafe_new_contract_state();
        let mut unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        ERC721::InternalImpl::initializer(ref unsafe_state_erc721, _name, _symbol);
        Ownable::InternalImpl::initializer( ref unsafe_state_ownable, _owner.try_into().unwrap());
    }

    // 查询Nft统称
    #[external(v0)]
    fn name(self: @ContractState) -> felt252 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721MetadataImpl::name(@unsafe_state)
    }

    // 查询Nft简称
    #[external(v0)]
    fn symbol(self: @ContractState) -> felt252 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721MetadataImpl::symbol(@unsafe_state)
    }

    // 查询Nft metaData
    #[external(v0)]
    fn tokenURI(self: @ContractState, token_id: u256) -> felt252 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        if (self.BlindBoxOpened.read() > 1)  {
            self.BlindTokenURI.read()
        }else {
            ERC721::ERC721MetadataImpl::token_uri(@unsafe_state, token_id)
        }
        
    }

    // 查询Nft url
    #[external(v0)]
    fn contractURI(self: @ContractState) -> felt252 {
       'https://bit.ly/3ueoihx'
    }

    // 查询nft状态
    #[external(v0)]
    fn checkNftStatus(self: @ContractState) -> u256 {
        self.WhiteListSwitch.read()
    }

     // 查询公开铸造是否开启
    #[external(v0)]
    fn checkNftPublicMintStatus(self: @ContractState) -> u256 {
        self.PublicMintSwitch.read()
    }

    // 查询nft盲盒状态
    #[external(v0)]
    fn checkNftBlindBoxOpenedStatus(self: @ContractState) -> u256 {
        self.BlindBoxOpened.read()
    }

    // 查询正在铸造的nft数量
    #[external(v0)]
    fn quantityBeingMint(self: @ContractState) -> u256 {
        self.TokenId.read()
    }

    // 查询nft总量
    #[external(v0)]
    fn totalSupply(self: @ContractState) -> u256 {
        u256_from_felt252(self.TotalSupply.read())
    }

    // 查询某账户拥有的Nft数量
    #[external(v0)]
    fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721Impl::balance_of(@unsafe_state, account)
    }

    // 根据token id 查询所有者的地址
    #[external(v0)]
    fn ownerOf(self: @ContractState, token_id: u256) -> ContractAddress {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721Impl::owner_of(@unsafe_state, token_id)
    }

    // 根据授权地址给接收地址来查询是否已授权
    #[external(v0)]
    fn isApprovedForAll(
        self: @ContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721Impl::is_approved_for_all(@unsafe_state, owner, operator)
    }

    // 根据token id查询授权的地址
    #[external(v0)]
    fn getApproved(self: @ContractState, token_id: u256) -> ContractAddress {
        let unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721Impl::get_approved(@unsafe_state, token_id)
    }

    // 根据授权账户给接收账户来设置授权
    #[external(v0)]
    fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721Impl::set_approval_for_all(ref unsafe_state, operator, approved)
    }

    // 更改owner权限
    #[external(v0)]
    fn changeOwner(ref self: ContractState, newOwner: ContractAddress) {
        let mut unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        Ownable::OwnableCamelOnlyImpl::transferOwnership(ref unsafe_state_ownable, newOwner);
    }

    // 设置公开铸造是否开启还是暂停
    #[external(v0)]
    fn changeNftPublicMintSwitch(ref self: ContractState, _publicMintSwitch: u256) {
        let unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        self.PublicMintSwitch.write(_publicMintSwitch);
    }

    // 管理员设置Nft白名单是否开启开启还是暂停
    #[external(v0)]
    fn changeNftWhiteListStatus(ref self: ContractState, _newSwitch: u256) {
        let unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        self.WhiteListSwitch.write(_newSwitch);
    }

    // 更改盲盒状态
    #[external(v0)]
    fn changeNftBlindBoxOpenedStatus(ref self: ContractState, _newBlindBoxOpened: u256) {
        let unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        self.BlindBoxOpened.write(_newBlindBoxOpened);
    }

    // 设置白名单的地址
    #[external(v0)]
    fn setWhiteList(ref self: ContractState, tos: Array<ContractAddress>) {
        let unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        let mut i: u256 = 0;
        let len: u256 = tos.len().into();
        loop {
            if(i >= len) {
                break ();
            }
            self.WhiteListUser.write(*tos.at(i.try_into().unwrap()), true);
            i += 1;
        }
        
    }

    // 设置Nft url
    #[external(v0)]
    fn setTokenURI(
        ref self: ContractState,
        token_id: u256,
        token_uri: felt252
    ) {
        let unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::InternalImpl::_set_token_uri(ref unsafe_state,token_id, token_uri);
    }

    // 白名单mint
    #[external(v0)]
    fn whiteListMint(ref self: ContractState, token_uri: felt252, to: ContractAddress, amount: u256) {
        assert(!to.is_zero(), Errors::INVALID_ACCOUNT);
        // 判断白名单是否开启
        assert(self.WhiteListSwitch.read() > 1, 'Whitelist is not enabled');
        // 判断用户是否在白名单内
        assert(self.WhiteListUser.read(to), 'Non-whitelisted users');
        let mut index: u256 = self.CurrentIndex.read();
        assert(
            amount <= u256_from_felt252(self.MintMaxAmount.read())
                && !self.MintLimited.read( (to, u256_from_felt252(self.MintMaxAmount.read()))),
            'Max per tx amount exceeded'
        );
        assert(
            index + amount <= totalSupply(@self) - u256_from_felt252(self.AirDrop.read()), 'Casting limit exceeded'
        );
        index += amount;

        if (index == u256_from_felt252(self.MintMaxAmount.read())) {
            self.MintLimited.write((to, index),true);
        } else {
            self.MintLimited.write((to, index),false);
        }

        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        let mut p: u256 = 0;
        let mut id: u256 = self.TokenId.read();
        loop {
            if (p >= amount) {
                break ();
            }
            id += 1;
            ERC721::InternalImpl::_mint(ref unsafe_state, to, id);
            ERC721::InternalImpl::_set_token_uri(ref unsafe_state, id, token_uri);
            self.TokenId.write(id);
            p += 1;
        }
    }

    // 公开mint
    #[external(v0)]
    fn publicMint(ref self: ContractState, to: ContractAddress, token_uri: felt252, amount: u256) {
        assert(!to.is_zero(), Errors::INVALID_ACCOUNT);
        assert(self.PublicMintSwitch.read() > 1, 'Not started yet');
        assert(!self.ReentrancyGuard_entered.read(), Errors::REENTRANT_CALL);
        self.ReentrancyGuard_entered.write(true);
        let caller = get_caller_address();
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        // eth合约地址
        let eth: ContractAddress = 0x49D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        // 收取eth铸造fee
        let value: u256 = u256_from_felt252(self.PublicMintPrice.read());
        let mut eth_erc20_token = ERC20CamelABIDispatcher { contract_address: eth };
        let mut unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        let owner: ContractAddress = Ownable::OwnableImpl::owner(@unsafe_state_ownable);
        // 将接收的0.0001 eth转给owner
        eth_erc20_token.transferFrom(caller, owner, value);
        let mut index: u256 = self.CurrentIndex.read();
        assert(
            amount <= u256_from_felt252(self.MintMaxAmount.read())
                && !self.MintLimited.read((to, u256_from_felt252(self.MintMaxAmount.read()))),
            'Max per tx amount exceeded'
        );
        assert(
            index + amount <= totalSupply(@self) - u256_from_felt252(self.AirDrop.read()), 'Casting limit exceeded'
        );
        index += amount;

        if (index == u256_from_felt252(self.MintMaxAmount.read())) {
            self.MintLimited.write((to, index), true);
        } else {
            self.MintLimited.write((to, index),false);
        }

        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        let mut p: u256 = 0;
        let mut id: u256 = self.TokenId.read();
        loop {
            if (p >= amount) {
                break ();
            }
            id += 1;
            ERC721::InternalImpl::_mint(ref unsafe_state, to, id);
            ERC721::InternalImpl::_set_token_uri(ref unsafe_state, id, token_uri);
            self.TokenId.write(id);
            p += 1;
        };

        self.ReentrancyGuard_entered.write(false);
    }

    // 管理员空投Nft
    #[external(v0)]
    fn freeAirDrop(ref self: ContractState, to: ContractAddress, tokenId: u256, tokenUri: felt252) {
        assert(!to.is_zero(), Errors::INVALID_ACCOUNT);
        let unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        let mut airDropTotal: u256 = u256_from_felt252(self.AirDrop.read());
        let mut id: u256 = self.TokenId.read();
        assert(
            airDropTotal > 0 && airDropTotal + quantityBeingMint(@self) <= totalSupply(@self),
            'Quantity exceeds limit'
        );
        id += 1;
        ERC721::InternalImpl::_mint(ref unsafe_state, to, id);
        ERC721::InternalImpl::_set_token_uri(ref unsafe_state, id, tokenUri);
    }

    // 授权Nft给某账户
    #[external(v0)]
    fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721Impl::approve(ref unsafe_state, to, token_id)
    }

    // 转移Nft拥有权给某账户
    #[external(v0)]
    fn transferFrom(
        ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    ) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721Impl::transfer_from(ref unsafe_state, from, to, token_id)
    }

    // 安全转移所有权给某账户
    // 安全传输意味着它检查接收者是否有效.它还可以接受发送给接收器的附加数据
    #[external(v0)]
    fn safeTransferFrom(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::ERC721Impl::safe_transfer_from(ref unsafe_state, from, to, token_id, data)
    }

    // 销毁 Token
    #[external(v0)]
    fn burn(ref self: ContractState, token_id: u256) {
        let mut unsafe_state = ERC721::unsafe_new_contract_state();
        ERC721::InternalImpl::_burn(ref unsafe_state, token_id);
    }


    // 可升级nft方法
    #[external(v0)]
    fn upgrade(ref self: ContractState, new_class_hash: felt252) {
        let newClassHash: ClassHash = new_class_hash.try_into().unwrap();
        let unsafe_state_ownable = Ownable::unsafe_new_contract_state();
        Ownable::InternalImpl::assert_only_owner(@unsafe_state_ownable);
        let mut unsafe_state = Upgradeable::unsafe_new_contract_state();
        Upgradeable::InternalImpl::_upgrade(ref unsafe_state, newClassHash);
    }

}
