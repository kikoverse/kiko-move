address 0x8355417c88d969f656935244641256ad {
module AptosKiko {
    
    use 0x1::Signer;
    use 0x1::Token;
    use 0x1::Account;

    const SELF: address = @0x8355417c88d969f656935244641256ad;

    const PERMISSION_DENIED: u64 = 250001;

    struct AptosKIKO has copy, drop, store {}

    struct Capability has key, store {
        mint: Token::MintCapability<AptosKIKO>,
        burn: Token::BurnCapability<AptosKIKO>
    }

    public fun init(sender: &signer) {
        let sender_ = Signer::address_of(sender);
        assert(SELF == sender_, PERMISSION_DENIED);        
        Token::register_token<AptosKIKO>(sender, 0);
        let mint_cap = Token::remove_mint_capability<AptosKIKO>(sender);
        let burn_cap = Token::remove_burn_capability<AptosKIKO>(sender);
        move_to(sender, Capability { 
            mint: mint_cap,
            burn: burn_cap
        });
    }

    fun mint(sender: &signer, amount: u128) acquires Capability {
        let sender_ = Signer::address_of(sender);
        assert(SELF == sender_, PERMISSION_DENIED);        
        let cap = borrow_global<Capability>(SELF);
        let token = Token::mint_with_capability<AptosKIKO>(&cap.mint, amount);
        Account::deposit_to_self(sender, token);
    }

    public(script) fun f_init(sender: signer) {
        init(&sender);
    }

    public(script) fun f_mint(sender: signer, amount: u128) acquires Capability {
        mint(&sender, amount);
    }

}
}