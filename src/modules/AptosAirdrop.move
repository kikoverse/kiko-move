address 0x8355417c88d969f656935244641256ad {
module AptosAirdrop {

    use 0x1::Event;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Token;
    use 0x1::Vector;
    
    const SELF: address = @0x8355417c88d969f656935244641256ad;

    const PERMISSION_DENIED: u64 = 210001;
    const INSUFFICIENT_BALANCE: u64 = 210002;

    struct ClaimEvent has drop, store {
        account: address,
        amount: u128,
        token_code: Token::TokenCode
    }

    struct TokenInfo<BoxToken: store> has key, store {
        token: Token::Token<BoxToken>,
        account: vector<address>,
        claim_events: Event::EventHandle<ClaimEvent>
    }

    public fun inject_token<BoxToken: store>(sender: &signer, amount: u128) acquires TokenInfo {
        let sender_ = Signer::address_of(sender);
        assert(SELF == sender_, PERMISSION_DENIED);
        if (!exists<TokenInfo<BoxToken>>(sender_)) {
            move_to(sender, TokenInfo<BoxToken> {
                token: Token::zero(),
                account: Vector::empty(),
                claim_events: Event::new_event_handle<ClaimEvent>(sender)
            });
        };
        let token = Account::withdraw<BoxToken>(sender, amount);
        let token_info = borrow_global_mut<TokenInfo<BoxToken>>(SELF);
        Token::deposit<BoxToken>(&mut token_info.token, token);
    }

    public fun claim_token<BoxToken: store>(sender: &signer) acquires TokenInfo {
        let sender_ = Signer::address_of(sender);
        let token_info = borrow_global_mut<TokenInfo<BoxToken>>(SELF);
        assert(0 < Token::value<BoxToken>(&token_info.token), INSUFFICIENT_BALANCE);
        let decimal = Token::scaling_factor<BoxToken>();
        Account::set_auto_accept_token(sender, true);
        Account::deposit_to_self(sender, Token::withdraw<BoxToken>(&mut token_info.token, decimal));
        Vector::push_back(&mut token_info.account, sender_);
        Event::emit_event(
            &mut token_info.claim_events,
            ClaimEvent {
                account: sender_,
                amount: decimal,
                token_code: Token::token_code<BoxToken>()
            }
        );
    }

    public(script) fun f_inject_token<BoxToken: store>(sender: signer, amount: u128) acquires TokenInfo {
        inject_token<BoxToken>(&sender, amount);
    }

    public(script) fun f_claim_token<BoxToken: store>(sender: signer) acquires TokenInfo {
        claim_token<BoxToken>(&sender);
    }

}
}