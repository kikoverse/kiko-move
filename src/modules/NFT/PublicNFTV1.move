address 0x8355417C88d969F656935244641256aD {
module PublicNFTV1_1 {
    use 0x1::Vector;
    use 0x1::Signer;
    use 0x1::Event;
    use 0x1::NFT;
    use 0x1::NFTGallery;

    const SELF_ADDRESS: address = @0x8355417C88d969F656935244641256aD;

    const PERMISSION_DENIED: u64 = 100001;

    // ******************** NFT ********************
    struct Meta has copy, store, drop {}

    struct Body has copy, store, drop {}

    struct TypeInfo has copy, store, drop {}

    struct Capability has key {
        owner: address,
        mint: NFT::MintCapability<Meta>
    }

    struct Info has key {
        nft_id: vector<u64>,
        info_id: vector<u64>
    }

    fun init_nft(
        sender: &signer,
        metadata: NFT::Metadata,
        owner: address
    ) {
        if (!exists<Capability>(Signer::address_of(sender))) {
            NFT::register<Meta, TypeInfo>(
                sender, 
                TypeInfo {},
                metadata
            );
            move_to(
                sender,
                Capability {
                    owner: owner,
                    mint: NFT::remove_mint_capability<Meta>(sender)
                }
            );
            move_to(
                sender,
                Info {
                    nft_id: Vector::empty(),
                    info_id: Vector::empty()
                }
            );
        }
    }

    fun mint_nft(
        sender: &signer,
        metadata: NFT::Metadata,
        info_id: u64
    ) acquires Capability, Gallery, Info {
        let creator = Signer::address_of(sender);
        let capability = borrow_global_mut<Capability>(SELF_ADDRESS);
        assert(capability.owner == creator, PERMISSION_DENIED);        
        let nft = NFT::mint_with_cap<Meta, Body, TypeInfo>(
            creator,
            &mut capability.mint,
            metadata,
            Meta {},
            Body {}
        );
        let id = NFT::get_id<Meta, Body>(&nft);
        NFTGallery::deposit(
            sender,
            nft
        );

        let info = borrow_global_mut<Info>(SELF_ADDRESS);        
        Vector::push_back(&mut info.nft_id, id);
        Vector::push_back(&mut info.info_id, info_id);

        Event::emit_event<NFTMintEvent<Meta, Body>>(
            &mut borrow_global_mut<Gallery>(SELF_ADDRESS).nft_mint_events,
            NFTMintEvent {
                creator: creator,
                id: id
            }
        );
    }

    // ******************** NFT Gallery ********************
    struct Gallery has key, store {
        nft_mint_events: Event::EventHandle<NFTMintEvent<Meta, Body>>,
    }

    struct NFTMintEvent<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        creator: address,
        id: u64,
    }

    fun init_gallery(sender: &signer) {
        if (!exists<Gallery>(Signer::address_of(sender))) {
            move_to(
                sender,
                Gallery {
                    nft_mint_events: Event::new_event_handle<NFTMintEvent<Meta, Body>>(sender)
                }
            );
        }
    }

    // ******************** NFT public function ********************
    public fun f_init_with_image(
        sender: &signer,
        name: vector<u8>,
        image: vector<u8>,
        description: vector<u8>,
        owner: address
    ) {
        assert(SELF_ADDRESS == Signer::address_of(sender), PERMISSION_DENIED);
        NFTGallery::accept<Meta, Body>(sender);
        init_nft(
            sender,
            NFT::new_meta_with_image(
                name,
                image,
                description
            ),
            owner
        );
        init_gallery(sender);
    }

    public fun f_mint_with_image(
        sender: &signer,
        name: vector<u8>,
        image: vector<u8>,
        description: vector<u8>,
        info_id: u64
    ) acquires Capability, Gallery, Info {
        mint_nft(
            sender,
            NFT::new_meta_with_image(
                name,
                image,
                description
            ),
            info_id
        );
    }

    // ******************** NFT script function ********************
    public(script) fun init_with_image(
        sender: signer,
        name: vector<u8>,
        image: vector<u8>,
        description: vector<u8>,
        owner: address
    ) {
        f_init_with_image(
            &sender,
            name,
            image,
            description,
            owner
        );
    }

    public(script) fun mint_with_image(
        sender: signer,
        name: vector<u8>,
        image: vector<u8>,
        description: vector<u8>,
        info_id: u64
    ) acquires Capability, Gallery, Info {
        f_mint_with_image(
            &sender,
            name,
            image,
            description,
            info_id
        );
    }

}
}
