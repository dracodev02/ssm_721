#[starknet::contract]
mod StarkSnowman {
    use starknet::storage::StoragePathEntry;
use ERC721Component::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::ERC721HooksEmptyImpl;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::ClassHash;
    use starknet::ContractAddress;
    use starknet::storage::{ StoragePointerReadAccess, StoragePointerWriteAccess, Map};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,

        total_supply: u256,

        contract_uri: ByteArray,

        base_uri: Map<u256, ByteArray>,

        token_id_counter: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, contract_uri: ByteArray, name: ByteArray, symbol: ByteArray, base_uri: ByteArray, total_supply: u256) {
        self.erc721.initializer(name, symbol, base_uri);
        self.ownable.initializer(owner);
        self.contract_uri.write(contract_uri);
        self.total_supply.write(total_supply);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn mint(
            ref self: ContractState,
            token_uri: ByteArray,
            token_id: u256,
        ) {
            // Token ID will be written from {1} to {total_supply}
           let total_supply = self.total_supply.read();
           let token_id_counter = self.token_id_counter.read(); // start from 0

           assert!(token_id_counter < total_supply, "All tokens have been minted"); // token id counter from 0 to 554
           assert!(self.base_uri.entry(token_id).read().len() == 0, "Token URI already set"); // if len of token_uri of token_id is not 0, token_uri already set
           let owner = self.ownable.Ownable_owner.read();

           self.erc721.mint(owner, token_id);
           self.base_uri.entry(token_id).write(token_uri);
           self.token_id_counter.write(token_id_counter + 1);
        }

        #[external(v0)]
        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.base_uri.entry(token_id).read()
        }

        #[external(v0)]
        fn max_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

     }

     #[generate_trait]
     #[abi(per_item)]
     impl SupportInterface of ISupportInterface {

        #[external(v0)]
        fn maxSupply(self: @ContractState) -> u256 {
            self.max_supply()
        }

        #[external(v0)]
        fn tokenURI(self: @ContractState, tokenURI : u256) -> ByteArray {
            self.token_uri(tokenURI)
        }
     }

}