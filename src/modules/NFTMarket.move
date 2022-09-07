address 0x7ed4261b68ddb20158109794bbab3ae7 {
module NFTMarket {

    use 0x1::Event;
    use 0x1::Account;
    use 0x1::Option::{Self, Option};
    use 0x1::Signer;
    use 0x1::Token;
    use 0x1::Vector;
    use 0x1::Timestamp;
    use 0x1::NFT::{Self, NFT};
    use 0x1::NFTGallery;
    use 0x7ed4261b68ddb20158109794bbab3ae7::KikoWhiteList;
    
    const NFT_MARKET_ADDRESS: address = @0x7ed4261b68ddb20158109794bbab3ae7;
    const NFT_MARKET_FEE_ADDRESS: address = @0x7ed4261b68ddb20158109794bbab3ae7;

    const MILLISECONDS_DAY: u64 = 86400000;
    const MILLISECONDS_5_MIN: u64 = 300000;

    // error
    const PERMISSION_DENIED: u64 = 200001;
    const OFFERING_NOT_EXISTS: u64 = 200002;
    const OFFERING_NOT_ON_SALE: u64 = 200003;
    const INSUFFICIENT_BALANCE: u64 = 200004;
    const ID_NOT_EXIST: u64 = 200005;
    const BID_FAILED: u64 = 200006;
    const NFT_SELL_INFO_NOT_EXISTS: u64 = 200007;
    const EXCESSIVE_FEE_RATE: u64 = 200008;
    const BOX_SELLING_NOT_EXIST: u64 = 200009;
    const BOX_SELLING_IS_EMPTY: u64 = 200010;
    const BOX_SELLING_PRICE_SMALL: u64 = 200011;
    const BOX_SELLING_INDEX_OUT_BOUNDS: u64 = 200012;
    const PRICE_TOO_LOW: u64 = 200013;
    const QUANTITY_EXCESSED: u64 = 200014;
    const AUCTION_DEADLINE_INVALID: u64 = 200015;
    const DISABLE: u64 = 200016;
    const UNEXPIRED: u64 = 200017;
    const TYPE_MISMATCH: u64 = 200018;
    const EXPIRED: u64 = 200019;
    const VERSION_NOT_EXIST: u64 = 200020;
    const NOT_SUPPORT_VERSION: u64 = 200021;

    // ******************** Config ********************
    struct Config has key, store {
        // creator fee, 10 mean 1%
        creator_fee: u128,
        // platform fee
        platform_fee: u128
    }

        struct VersionV1 has key, store {
        version: u8
    }

    fun check_verison(_version: u8) {//acquires VersionV1 {
        // assert(exists<VersionV1>(NFT_MARKET_ADDRESS), VERSION_NOT_EXIST);
        // assert(borrow_global<VersionV1>(NFT_MARKET_ADDRESS).version == version, NOT_SUPPORT_VERSION);
        assert(2 == _version, NOT_SUPPORT_VERSION);
    }

    public fun update_verison(sender: &signer, version: u8) acquires VersionV1 {
        let sender_address = Signer::address_of(sender);
        assert(NFT_MARKET_ADDRESS == sender_address, PERMISSION_DENIED);
        if (!exists<VersionV1>(sender_address)) {
            move_to(sender, VersionV1 {
                version: 0
            });
        };

        let version_v1 = borrow_global_mut<VersionV1>(NFT_MARKET_ADDRESS);
        version_v1.version = version;
    }

    // init
    public fun init_config(sender: &signer, creator_fee: u128, platform_fee: u128) {
        assert(Signer::address_of(sender) == NFT_MARKET_ADDRESS, PERMISSION_DENIED);
        assert(creator_fee < 1000 && platform_fee < 1000, EXCESSIVE_FEE_RATE);

        move_to<Config>(sender, Config {
            creator_fee: creator_fee,
            platform_fee: platform_fee,
        });
    }

    // update
    public fun update_config(sender: &signer, creator_fee: u128, platform_fee: u128)
    acquires Config {
        assert(Signer::address_of(sender) == NFT_MARKET_ADDRESS, PERMISSION_DENIED);
        assert(creator_fee < 1000 && platform_fee < 1000, EXCESSIVE_FEE_RATE);

        let config = borrow_global_mut<Config>(NFT_MARKET_ADDRESS);
        config.creator_fee = creator_fee;
        config.platform_fee = platform_fee;
    }

    // get fee
    public fun get_fee(amount: u128): (u128, u128) acquires Config {
        let config = borrow_global<Config>(NFT_MARKET_ADDRESS);
        (amount * config.creator_fee / 1000, amount * config.platform_fee / 1000)
    }

    // ******************** Initial Offering ********************
    // box initial offering struct
    struct BoxOffering<BoxToken: store, PayToken: store> has key, store {
        // box tokens
        box_tokens: Token::Token<BoxToken>,
        // selling price for PayToken
        selling_price: u128,
        // selling start time for box
        selling_time: u64,
        offering_events: Event::EventHandle<BoxOfferingEvent>,
        sell_events: Event::EventHandle<BoxOfferingSellEvent>,
    }

    // box initial white offering struct
    struct BoxWhiteOffering<BoxToken: store, PayToken: store> has key, store {
        // box tokens
        box_tokens: Token::Token<BoxToken>,
        // selling price for PayToken
        selling_price: u128,
        // selling start time for box
        selling_time: u64,
        offering_events: Event::EventHandle<BoxOfferingEvent>,
        sell_events: Event::EventHandle<BoxOfferingSellEvent>,
    }

    // box initial offering event
    struct BoxOfferingEvent has drop, store {
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // total price
        total_price: u128,
    }

    // box offering sell event
    struct BoxOfferingSellEvent has drop, store {
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // total price
        total_price: u128,
        // buyer address
        buyer: address,
    }

    // init market resource for different PayToken
    public fun init_market<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: &signer,
        creator: address,
    ) {
        let sender_address = Signer::address_of(sender);
        assert(sender_address == NFT_MARKET_ADDRESS, PERMISSION_DENIED);
        // if (!exists<BoxSelling<BoxToken, PayToken>>(sender_address)) {
        //     move_to(sender, BoxSelling<BoxToken, PayToken> {
        //         items: Vector::empty(),
        //         creator: creator,
        //         last_id: 0u128,
        //         sell_events: Event::new_event_handle<BoxSellEvent>(sender),
        //         change_price_events: Event::new_event_handle<BoxChangePriceEvent>(sender),
        //         offline_events: Event::new_event_handle<BoxOfflineEvent>(sender),
        //         bid_events: Event::new_event_handle<BoxBidEvent>(sender),
        //         buy_events: Event::new_event_handle<BoxBuyEvent>(sender),
        //         accept_bid_events: Event::new_event_handle<BoxAcceptBidEvent>(sender)
        //     });
        // };
        // if (!exists<NFTSelling<NFTMeta, NFTBody, PayToken>>(sender_address)) {
        //     move_to(sender, NFTSelling<NFTMeta, NFTBody, PayToken> {
        //         items: Vector::empty(),
        //         sell_events: Event::new_event_handle<NFTSellEvent<NFTMeta, NFTBody>>(sender),
        //         change_price_events: Event::new_event_handle<NFTChangePriceEvent<NFTMeta, NFTBody>>(sender),
        //         offline_events: Event::new_event_handle<NFTOfflineEvent<NFTMeta, NFTBody>>(sender),
        //         bid_events: Event::new_event_handle<NFTBidEvent<NFTMeta, NFTBody>>(sender),
        //         buy_events: Event::new_event_handle<NFTBuyEvent<NFTMeta, NFTBody>>(sender),
        //         accept_bid_events: Event::new_event_handle<NFTAcceptBidEvent<NFTMeta, NFTBody>>(sender)
        //     });
        // };
        if (!exists<BoxSellingV2<BoxToken, PayToken>>(sender_address)) {
            move_to(sender, BoxSellingV2<BoxToken, PayToken> {
                items: Vector::empty(),
                creator: creator,
                last_id: 0,
                sell_events: Event::new_event_handle<BoxSellEventV2>(sender),
                offline_events: Event::new_event_handle<BoxOfflineEventV2>(sender),
                bid_events: Event::new_event_handle<BoxBidEventV2>(sender),
                buy_events: Event::new_event_handle<BoxBuyEventV2>(sender),
                accept_bid_events: Event::new_event_handle<BoxAcceptBidEventV2>(sender)
            });
        };
        if (!exists<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(sender_address)) {
            move_to(sender, NFTSellingV2<NFTMeta, NFTBody, PayToken> {
                items: Vector::empty(),
                sell_events: Event::new_event_handle<NFTSellEventV2<NFTMeta, NFTBody>>(sender),
                offline_events: Event::new_event_handle<NFTOfflineEventV2<NFTMeta, NFTBody>>(sender),
                bid_events: Event::new_event_handle<NFTBidEventV2<NFTMeta, NFTBody>>(sender),
                buy_events: Event::new_event_handle<NFTBuyEventV2<NFTMeta, NFTBody>>(sender),
                accept_bid_events: Event::new_event_handle<NFTAcceptBidEventV2<NFTMeta, NFTBody>>(sender)
            });
        };
        
        // auto accept token
        Account::set_auto_accept_token(sender, true);
    }

    // box initial offering
    public fun box_initial_white_offering<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: &signer,
        box_amount: u128,
        selling_price: u128,
        selling_time: u64,
        creator: address,
    ) acquires BoxWhiteOffering {
        let sender_address = Signer::address_of(sender);
        assert(sender_address == NFT_MARKET_ADDRESS, PERMISSION_DENIED);
        assert(0 < selling_price, PRICE_TOO_LOW);

        // check exists
        if (!exists<BoxWhiteOffering<BoxToken, PayToken>>(sender_address)) {
            move_to(sender, BoxWhiteOffering<BoxToken, PayToken> {
                box_tokens: Token::zero(),
                selling_price,
                selling_time,
                offering_events: Event::new_event_handle<BoxOfferingEvent>(sender),
                sell_events: Event::new_event_handle<BoxOfferingSellEvent>(sender),
            });
        };
        let offering = borrow_global_mut<BoxWhiteOffering<BoxToken, PayToken>>(sender_address);
        // transfer box to offering pool
        assert(Account::balance<BoxToken>(sender_address) >= box_amount, INSUFFICIENT_BALANCE);
        let box_tokens = Account::withdraw<BoxToken>(sender, box_amount);
        Token::deposit<BoxToken>(&mut offering.box_tokens, box_tokens);
        // init other market
        init_market<NFTMeta, NFTBody, BoxToken, PayToken>(sender, creator);
    }

    // box initial offering
    public fun box_initial_offering<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: &signer,
        box_amount: u128,
        selling_price: u128,
        selling_time: u64,
        creator: address,
    ) acquires BoxOffering {
        let sender_address = Signer::address_of(sender);
        assert(sender_address == NFT_MARKET_ADDRESS, PERMISSION_DENIED);
        assert(0 < selling_price, PRICE_TOO_LOW);

        // check exists
        if (!exists<BoxOffering<BoxToken, PayToken>>(sender_address)) {
            move_to(sender, BoxOffering<BoxToken, PayToken> {
                box_tokens: Token::zero(),
                selling_price,
                selling_time,
                offering_events: Event::new_event_handle<BoxOfferingEvent>(sender),
                sell_events: Event::new_event_handle<BoxOfferingSellEvent>(sender),
            });
        };
        let offering = borrow_global_mut<BoxOffering<BoxToken, PayToken>>(sender_address);
        // transfer box to offering pool
        assert(Account::balance<BoxToken>(sender_address) >= box_amount, INSUFFICIENT_BALANCE);
        let box_tokens = Account::withdraw<BoxToken>(sender, box_amount);
        Token::deposit<BoxToken>(&mut offering.box_tokens, box_tokens);
        // init other market
        init_market<NFTMeta, NFTBody, BoxToken, PayToken>(sender, creator);
    }

    public fun box_offering_white_update<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: &signer,
        selling_price: u128,
        selling_time: u64,
    ) acquires BoxWhiteOffering {
        let sender_address = Signer::address_of(sender);
        assert(sender_address == NFT_MARKET_ADDRESS, PERMISSION_DENIED);
        // check exists
        assert(exists<BoxWhiteOffering<BoxToken, PayToken>>(sender_address), OFFERING_NOT_EXISTS);
        let offering = borrow_global_mut<BoxWhiteOffering<BoxToken, PayToken>>(sender_address);
        offering.selling_price = selling_price;
        offering.selling_time = selling_time;
    }

    public fun box_offering_update<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: &signer,
        selling_price: u128,
        selling_time: u64,
    ) acquires BoxOffering {
        let sender_address = Signer::address_of(sender);
        assert(sender_address == NFT_MARKET_ADDRESS, PERMISSION_DENIED);
        // check exists
        assert(exists<BoxOffering<BoxToken, PayToken>>(sender_address), OFFERING_NOT_EXISTS);
        let offering = borrow_global_mut<BoxOffering<BoxToken, PayToken>>(sender_address);
        offering.selling_price = selling_price;
        offering.selling_time = selling_time;
    }

    // buy box from offering
    public fun box_buy_from_offering<BoxToken: store, PayToken: store>(sender: &signer, quantity: u128)
    acquires BoxOffering {
        assert(exists<BoxOffering<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        let offering = borrow_global_mut<BoxOffering<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        assert(Timestamp::now_milliseconds() >= offering.selling_time, OFFERING_NOT_ON_SALE);
        let sender_address = Signer::address_of(sender);
        assert(quantity <= 5, QUANTITY_EXCESSED);
        // transfer PayToken to platform
        let total_price = offering.selling_price * quantity;
        assert(Account::balance<PayToken>(sender_address) >= total_price, INSUFFICIENT_BALANCE);
        Account::pay_from<PayToken>(sender, NFT_MARKET_ADDRESS, total_price);
        // transfer box to buyer
        let box_tokens = Token::withdraw<BoxToken>(&mut offering.box_tokens, quantity);
        Account::deposit_to_self(sender, box_tokens);
        // emit event
        Event::emit_event(
            &mut offering.sell_events,
            BoxOfferingSellEvent {
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity,
                total_price,
                buyer: sender_address,
            }
        );
    }

    // buy box from white offering
    public fun box_buy_from_white_offering<BoxToken: store, PayToken: store>(sender: &signer, quantity: u128, box_offering_token: u64)
    acquires BoxWhiteOffering {
        assert(exists<BoxWhiteOffering<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        let offering = borrow_global_mut<BoxWhiteOffering<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        assert(Timestamp::now_milliseconds() >= offering.selling_time, OFFERING_NOT_ON_SALE);
        let sender_address = Signer::address_of(sender);
        // assert(quantity <= 5, QUANTITY_EXCESSED);
        // transfer PayToken to platform
        let total_price = offering.selling_price * quantity;
        assert(Account::balance<PayToken>(sender_address) >= total_price, INSUFFICIENT_BALANCE);
        Account::pay_from<PayToken>(sender, NFT_MARKET_ADDRESS, total_price);
        //update white list
        KikoWhiteList::update_amount(sender, box_offering_token, (quantity as u8));
        // transfer box to buyer
        let box_tokens = Token::withdraw<BoxToken>(&mut offering.box_tokens, quantity);
        Account::deposit_to_self(sender, box_tokens);
        // emit event
        Event::emit_event(
            &mut offering.sell_events,
            BoxOfferingSellEvent {
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity,
                total_price,
                buyer: sender_address,
            }
        );
    }

    // ******************** Box Transaction ********************
    // box sell listing
    struct BoxSelling<BoxToken: store, PayToken: store> has key, store {
        // selling list
        items: vector<BoxSellInfo<BoxToken, PayToken>>,
        creator: address,
        last_id: u128,
        sell_events: Event::EventHandle<BoxSellEvent>,
        change_price_events: Event::EventHandle<BoxChangePriceEvent>,
        offline_events: Event::EventHandle<BoxOfflineEvent>,
        bid_events: Event::EventHandle<BoxBidEvent>,
        buy_events: Event::EventHandle<BoxBuyEvent>,
        accept_bid_events: Event::EventHandle<BoxAcceptBidEvent>,
    }

    // box sell info
    struct BoxSellInfo<BoxToken: store, PayToken: store> has store {
        id: u128,
        seller: address,
        // box tokens for selling
        box_tokens: Token::Token<BoxToken>,
        // selling price
        selling_price: u128,
        // top price bid tokens
        bid_tokens: Token::Token<PayToken>,
        // buyer address
        bidder: address,
    }

    // box sell event
    struct BoxSellEvent has drop, store {
        // id
        id: u128,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // selling price
        selling_price: u128,
    }

    // box change price event
    struct BoxChangePriceEvent has drop, store {
        // id
        id: u128,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // selling price
        before_price: u128,
        after_price: u128,
        // bidder address
        bidder: address,
        // bid price, lower than selling price
        bid_price: u128,
    }

    // box offline event
    struct BoxOfflineEvent has drop, store {
        // id
        id: u128,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // selling price
        selling_price: u128,
        // buyer address
        bidder: address,
        // bid price, lower than selling price
        bid_price: u128,
    }

    // box offer price event
    struct BoxBidEvent has drop, store {
        // id
        id: u128,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // selling price
        selling_price: u128,
        // bidder address
        bidder: address,
        // bid price, lower than selling price
        bid_price: u128,
        // previous bidder address
        prev_bidder: address,
        // previous bidder price
        prev_bid_price: u128,
    }

    // box buy event
    struct BoxBuyEvent has drop, store {
        // id
        id: u128,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // final price
        final_price: u128,
        // buyer address
        buyer: address,
        // previous bidder address
        prev_bidder: address,
        // previous bidder price
        prev_bid_price: u128,
        // creator fee
        creator_fee: u128,
        // platform fee
        platform_fee: u128,
    }

    // box accept bid event
    struct BoxAcceptBidEvent has drop, store {
        // id
        id: u128,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // selling price
        selling_price: u128,
        // final price
        final_price: u128,
        // bidder address
        bidder: address,
        // creator fee
        creator_fee: u128,
        // platform fee
        platform_fee: u128,
    }

    // box sell
    public fun box_sell<BoxToken: store, PayToken: store>(seller: &signer, selling_price: u128) acquires BoxSelling {
        check_verison(1);
        assert(exists<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        assert(selling_price > 0, PRICE_TOO_LOW);

        let seller_address = Signer::address_of(seller);

        let box_selling = borrow_global_mut<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        box_selling.last_id = box_selling.last_id + 1;
        let withdraw_box_token = Account::withdraw<BoxToken>(seller, 1);
        let new_box = BoxSellInfo<BoxToken, PayToken> {
            id: box_selling.last_id,
            seller: seller_address,
            box_tokens: withdraw_box_token,
            selling_price: selling_price,
            bid_tokens: Token::zero<PayToken>(),
            bidder: @0x1,
        };
        Vector::push_back(&mut box_selling.items, new_box);
        // accept PayToken
        if (!Account::is_accepts_token<PayToken>(seller_address)){
            Account::do_accept_token<PayToken>(seller);
        };

        Event::emit_event(
            &mut box_selling.sell_events,
            BoxSellEvent {
                id: box_selling.last_id,
                seller: seller_address,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                selling_price: selling_price,
            }
        );
    }

    // box change price
    public fun box_change_price<BoxToken: store, PayToken: store>(seller: &signer, id: u128, selling_price: u128) acquires BoxSelling {
        check_verison(1);
        assert(exists<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        assert(selling_price > 0, PRICE_TOO_LOW);

        // find box
        let box_selling = borrow_global_mut<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(len > 0, BOX_SELLING_IS_EMPTY);
        let seller_address = Signer::address_of(seller);
        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        let k = 0;
        while ( k < len) {
            if (box_sell_info.id == id) {
                break
            };
            k = k + 1;
            assert(k < len, BOX_SELLING_INDEX_OUT_BOUNDS);
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
        };
        // check seller
        assert(seller_address == box_sell_info.seller, PERMISSION_DENIED);

        // check higher than bid price
        let bid_price = Token::value<PayToken>(&box_sell_info.bid_tokens);
        if (bid_price > 0) {
            assert(selling_price > bid_price, PRICE_TOO_LOW);
        };
        // change price
        let before_price = box_sell_info.selling_price;
        box_sell_info.selling_price = selling_price;
        Event::emit_event(
            &mut box_selling.change_price_events,
            BoxChangePriceEvent {
                id: box_sell_info.id,
                seller: seller_address,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                before_price: before_price,
                after_price: selling_price,
                bidder: box_sell_info.bidder,
                bid_price: bid_price,
            }
        );
    }

    // box offline
    public fun box_offline<BoxToken: store, PayToken: store>(seller: &signer, id: u128) acquires BoxSelling {
        check_verison(1);
        assert(exists<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        // find box
        let box_selling = borrow_global_mut<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(len > 0, BOX_SELLING_IS_EMPTY);
        let seller_address = Signer::address_of(seller);
        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        let k = 0;
        while ( k < len) {
            if (box_sell_info.id == id) {
                break
            };
            k = k + 1;
            assert(k < len, BOX_SELLING_INDEX_OUT_BOUNDS);
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
        };
        // check seller
        assert(seller_address == box_sell_info.seller, PERMISSION_DENIED);

        // give back bidToken to bidder
        let bid_amount = Token::value<PayToken>(&box_sell_info.bid_tokens);
        if (bid_amount > 0) {
            let bid_tokens = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, bid_amount);
            Account::deposit(box_sell_info.bidder, bid_tokens);
        };
        // take back box
        let box_tokens = Token::withdraw<BoxToken>(&mut box_sell_info.box_tokens, 1);
        Account::deposit(box_sell_info.seller, box_tokens);
        // emit event
        Event::emit_event(
            &mut box_selling.offline_events,
            BoxOfflineEvent {
                id: box_sell_info.id,
                seller: box_sell_info.seller,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                selling_price: box_sell_info.selling_price,
                bidder: box_sell_info.bidder,
                bid_price: bid_amount,
            }
        );
        // destory
        let remove_box_sell_info = Vector::swap_remove<BoxSellInfo<BoxToken, PayToken>>(&mut box_selling.items, k);
        let BoxSellInfo<BoxToken, PayToken> {
            id: _,
            seller: _,
            box_tokens,
            selling_price: _,
            bid_tokens,
            bidder: _,
        } = remove_box_sell_info;
        Token::destroy_zero(box_tokens);
        Token::destroy_zero(bid_tokens);
    }

    // box accept offer price
    public fun box_accept_bid<BoxToken: store, PayToken: store>(seller: &signer, id: u128) acquires BoxSelling, Config {
        check_verison(1);
        assert(exists<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);

        let box_selling = borrow_global_mut<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(len > 0, BOX_SELLING_IS_EMPTY);

        let seller_address = Signer::address_of(seller);

        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        let k = 0;
        while ( k < len) {
            if (box_sell_info.id == id) {
                break
            };
            k = k + 1;
            assert(k < len, BOX_SELLING_INDEX_OUT_BOUNDS);
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
        };
        // check seller
        assert(seller_address == box_sell_info.seller, PERMISSION_DENIED);

        let withdraw_box_token = Token::withdraw<BoxToken>(&mut box_sell_info.box_tokens, 1);
        Account::deposit(box_sell_info.bidder, withdraw_box_token);

        let bid_amount = Token::value<PayToken>(&box_sell_info.bid_tokens);

        let (creator_fee, platform_fee) = get_fee(bid_amount);

        let creator_fee_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, creator_fee);
        Account::deposit<PayToken>(box_selling.creator, creator_fee_token);

        let platform_fee_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, platform_fee);
        Account::deposit<PayToken>(NFT_MARKET_ADDRESS, platform_fee_token);

        let surplus_amount = bid_amount - creator_fee - platform_fee;
        let withdraw_bid_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, surplus_amount);
        Account::deposit(seller_address, withdraw_bid_token);

        Event::emit_event(
            &mut box_selling.accept_bid_events,
            BoxAcceptBidEvent {
                id: box_sell_info.id,
                seller: box_sell_info.seller,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                selling_price: box_sell_info.selling_price,
                final_price: bid_amount,
                bidder: box_sell_info.bidder,
                creator_fee: creator_fee,
                platform_fee: platform_fee,
            }
        );

        let remove_box_sell_info = Vector::swap_remove<BoxSellInfo<BoxToken, PayToken>>(&mut box_selling.items, k);
        let BoxSellInfo<BoxToken, PayToken> {
            id: _,
            seller: _,
            box_tokens,
            selling_price: _,
            bid_tokens,
            bidder: _,
        } = remove_box_sell_info;
        Token::destroy_zero(box_tokens);
        Token::destroy_zero(bid_tokens);
    }

    // box bid
    public fun box_bid<BoxToken: store, PayToken: store>(buyer: &signer, id: u128, price: u128) acquires BoxSelling, Config {
        check_verison(1);
        assert(exists<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        assert(price > 0, PRICE_TOO_LOW);

        let box_selling = borrow_global_mut<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(len > 0, BOX_SELLING_IS_EMPTY);

        let buyer_address = Signer::address_of(buyer);

        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        let k = 0;
        while ( k < len) {
            if (box_sell_info.id == id) {
                break
            };
            k = k + 1;
            assert(k < len, BOX_SELLING_INDEX_OUT_BOUNDS);
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
        };

        if (price >= box_sell_info.selling_price) {
            // buy
            box_buy<BoxToken, PayToken>(buyer, id);
        } else {
            let bid_price = Token::value<PayToken>(&box_sell_info.bid_tokens);
            let prev_bidder = box_sell_info.bidder;
            // There is already a quotation
            if (bid_price > 0u128) {
                // The latest quotation is less than or equal to the previous highest quotation
                assert(price > bid_price, BOX_SELLING_PRICE_SMALL);

                // If the latest quotation is greater than the previous highest quotation, the previous users will be returned
                let withdraw_bid_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, bid_price);
                Account::deposit<PayToken>(box_sell_info.bidder, withdraw_bid_token);
            };

            let withdraw_buy_box_token = Account::withdraw<PayToken>(buyer, price);
            Token::deposit(&mut box_sell_info.bid_tokens, withdraw_buy_box_token);

            box_sell_info.bidder = buyer_address;
            // accept BoxToken
            if (!Account::is_accepts_token<BoxToken>(buyer_address)){
                Account::do_accept_token<BoxToken>(buyer);
            };

            Event::emit_event(
                &mut box_selling.bid_events,
                BoxBidEvent {
                    id: box_sell_info.id,
                    seller: box_sell_info.seller,
                    box_token_code: Token::token_code<BoxToken>(),
                    pay_token_code: Token::token_code<PayToken>(),
                    quantity: 1,
                    selling_price: box_sell_info.selling_price,
                    bidder: buyer_address,
                    bid_price: price,
                    prev_bidder: prev_bidder,
                    prev_bid_price: bid_price,
                }
            );
        };
    }

    // box buy
    public fun box_buy<BoxToken: store, PayToken: store>(buyer: &signer, id: u128) acquires BoxSelling, Config {
        check_verison(1);
        assert(exists<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);

        let box_selling = borrow_global_mut<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(len > 0, BOX_SELLING_IS_EMPTY);

        let buyer_address = Signer::address_of(buyer);

        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        let k = 0;
        while ( k < len) {
            if (box_sell_info.id == id) {
                break
            };
            k = k + 1;
            assert(k < len, BOX_SELLING_INDEX_OUT_BOUNDS);
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
        };
        let seller_address = box_sell_info.seller;
        let selling_price = box_sell_info.selling_price;

        let bid_price = Token::value<PayToken>(&box_sell_info.bid_tokens);
        // There is already a quotation
        if (bid_price > 0u128) {
            // If the latest quotation is greater than the previous highest quotation, the previous users will be returned
            let withdraw_bid_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, bid_price);
            Account::deposit<PayToken>(box_sell_info.bidder, withdraw_bid_token);
        };

        let withdraw_box_token = Token::withdraw<BoxToken>(&mut box_sell_info.box_tokens, 1);
        Account::deposit_to_self(buyer, withdraw_box_token);

        let (creator_fee, platform_fee) = get_fee(selling_price);

        let creator_fee_token = Account::withdraw<PayToken>(buyer, creator_fee);
        Account::deposit<PayToken>(box_selling.creator, creator_fee_token);

        let platform_fee_token = Account::withdraw<PayToken>(buyer, platform_fee);
        Account::deposit<PayToken>(NFT_MARKET_ADDRESS, platform_fee_token);

        let surplus_amount = selling_price - creator_fee - platform_fee;
        let withdraw_buy_box_token = Account::withdraw<PayToken>(buyer, surplus_amount);
        Account::deposit(seller_address, withdraw_buy_box_token);

        Event::emit_event(
            &mut box_selling.buy_events,
            BoxBuyEvent {
                id: box_sell_info.id,
                seller: box_sell_info.seller,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                buyer: buyer_address,
                final_price: selling_price,
                prev_bidder: box_sell_info.bidder,
                prev_bid_price: bid_price,
                creator_fee: creator_fee,
                platform_fee: platform_fee,
            }
        );

        let remove_box_sell_info = Vector::swap_remove<BoxSellInfo<BoxToken, PayToken>>(&mut box_selling.items, k);
        let BoxSellInfo<BoxToken, PayToken> {
            id: _,
            seller: _,
            box_tokens,
            selling_price: _,
            bid_tokens,
            bidder: _,
        } = remove_box_sell_info;
        Token::destroy_zero(box_tokens);
        Token::destroy_zero(bid_tokens);
    }
    
    // cancel all order
    public fun box_offline_all<BoxToken: store, PayToken: store>(sender: &signer, amount: u64) acquires BoxSelling {
        assert(exists<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        assert(Signer::address_of(sender) == NFT_MARKET_ADDRESS, PERMISSION_DENIED);

        let box_selling = borrow_global_mut<BoxSelling<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        if (amount == 0 || amount > len) {
            amount = len;
        };
        let i = 0;
        while(i < amount) {
            let box_sell_info = Vector::pop_back(&mut box_selling.items);
            let bid_amount = Token::value<PayToken>(&box_sell_info.bid_tokens);
            if (0 < bid_amount) {
                let bid_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, bid_amount);
                Account::deposit(box_sell_info.bidder, bid_token);
            };
            
            let box_token = Token::withdraw<BoxToken>(&mut box_sell_info.box_tokens, 1);
            Account::deposit(box_sell_info.seller, box_token);
            
            Event::emit_event(
                &mut box_selling.offline_events,
                BoxOfflineEvent {
                    id: box_sell_info.id,
                    seller: box_sell_info.seller,
                    box_token_code: Token::token_code<BoxToken>(),
                    pay_token_code: Token::token_code<PayToken>(),
                    quantity: 1,
                    selling_price: box_sell_info.selling_price,
                    bidder: box_sell_info.bidder,
                    bid_price: bid_amount,
                }
            );
            let BoxSellInfo<BoxToken, PayToken> {
                id: _,
                seller: _,
                box_tokens,
                selling_price: _,
                bid_tokens,
                bidder: _,
            } = box_sell_info;
            Token::destroy_zero(box_tokens);
            Token::destroy_zero(bid_tokens);

            i = i + 1;
        }
    }

    // ******************** Box Transaction v2 ********************
    // box sell listing
    struct BoxSellingV2<BoxToken: store, PayToken: store> has key, store {
        // selling list
        items: vector<BoxSellInfoV2<BoxToken, PayToken>>,
        creator: address,
        last_id: u128,
        sell_events: Event::EventHandle<BoxSellEventV2>,
        offline_events: Event::EventHandle<BoxOfflineEventV2>,
        bid_events: Event::EventHandle<BoxBidEventV2>,
        buy_events: Event::EventHandle<BoxBuyEventV2>,
        accept_bid_events: Event::EventHandle<BoxAcceptBidEventV2>,
    }

    // box sell info
    struct BoxSellInfoV2<BoxToken: store, PayToken: store> has store {
        id: u128,
        // 1: fix price, 2: auction
        type: u64,
        // seller
        seller: address,
        // box tokens for selling
        box_tokens: Token::Token<BoxToken>,
        // selling price
        selling_price: u128,
        // top price bid tokens
        bid_tokens: Token::Token<PayToken>,
        // buyer address
        bidder: address,
        // end time
        end_time: u128,
    }

    // box sell event
    struct BoxSellEventV2 has drop, store {
        // id
        id: u128,
        // sell type
        type: u64,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // selling price
        selling_price: u128,
        // end time
        end_time: u128,
    }

    // box offline event
    struct BoxOfflineEventV2 has drop, store {
        // id
        id: u128,
        // sell type
        type: u64,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // selling price
        selling_price: u128,
        // buyer address
        bidder: address,
        // bid price
        bid_price: u128,
    }

    // box buy event
    struct BoxBuyEventV2 has drop, store {
        // id
        id: u128,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // final price
        final_price: u128,
        // buyer address
        buyer: address,
        // previous bidder address
        prev_bidder: address,
        // previous bidder price
        prev_bid_price: u128,
        // creator fee
        creator_fee: u128,
        // platform fee
        platform_fee: u128,
    }

    // box bid price event
    struct BoxBidEventV2 has drop, store {
        // id
        id: u128,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // selling price
        selling_price: u128,
        // bidder address
        bidder: address,
        // bid price
        bid_price: u128,
        // previous bidder address
        prev_bidder: address,
        // previous bidder price
        prev_bid_price: u128,
        // end time
        end_time: u128,
    }

    // box accept bid event
    struct BoxAcceptBidEventV2 has drop, store {
        // id
        id: u128,
        // seller address
        seller: address,
        box_token_code: Token::TokenCode,
        pay_token_code: Token::TokenCode,
        // box quantity
        quantity: u128,
        // selling price
        selling_price: u128,
        // final price
        final_price: u128,
        // bidder address
        bidder: address,
        // creator fee
        creator_fee: u128,
        // platform fee
        platform_fee: u128,
    }

    public fun box_sell_fix_price<BoxToken: store, PayToken: store>(sender: &signer, price: u128) acquires BoxSellingV2 {
        check_verison(2);
        assert(exists<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        assert(0 < price, PRICE_TOO_LOW);

        let seller = Signer::address_of(sender);
        let end_time = (Timestamp::now_milliseconds() as u128);
        let box_selling = borrow_global_mut<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        box_selling.last_id = box_selling.last_id + 1;        
        Vector::push_back(
            &mut box_selling.items, 
            BoxSellInfoV2 {
                id: box_selling.last_id,
                type: 1,
                seller: seller,
                box_tokens: Account::withdraw<BoxToken>(sender, 1),
                selling_price: price,
                bid_tokens: Token::zero<PayToken>(),
                bidder: @0x1,
                end_time: end_time
            }
        );

        if (!Account::is_accepts_token<PayToken>(seller)){
            Account::do_accept_token<PayToken>(sender);
        };

        Event::emit_event(
            &mut box_selling.sell_events,
            BoxSellEventV2 {
                id: box_selling.last_id,
                type: 1,
                seller: seller,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                selling_price: price,
                end_time: end_time
            }
        );
    }

    public fun box_sell_auction<BoxToken: store, PayToken: store>(sender: &signer, price: u128, end_day: u64) acquires BoxSellingV2 {
        check_verison(2);
        assert(exists<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        assert(0 < price, PRICE_TOO_LOW);
        assert(1 <= end_day && end_day <= 7, AUCTION_DEADLINE_INVALID);

        let seller = Signer::address_of(sender);
        let end_time = ((Timestamp::now_milliseconds() + end_day * MILLISECONDS_DAY) as u128);
        let box_selling = borrow_global_mut<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        box_selling.last_id = box_selling.last_id + 1;
        Vector::push_back(
            &mut box_selling.items,
            BoxSellInfoV2<BoxToken, PayToken> {
                id: box_selling.last_id,
                type: 2,
                seller: seller,
                box_tokens: Account::withdraw<BoxToken>(sender, 1),
                selling_price: price,
                bid_tokens: Token::zero<PayToken>(),
                bidder: @0x1,
                end_time: end_time
            }
        );
        
        if (!Account::is_accepts_token<PayToken>(seller)){
            Account::do_accept_token<PayToken>(sender);
        };

        Event::emit_event(
            &mut box_selling.sell_events,
            BoxSellEventV2 {
                id: box_selling.last_id,
                type: 2,
                seller: seller,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                selling_price: price,
                end_time: end_time
            }
        );
    }

    public fun box_buy_fix_price<BoxToken: store, PayToken: store>(sender: &signer, id: u128) acquires BoxSellingV2, Config {
        check_verison(2);
        assert(exists<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        let box_selling = borrow_global_mut<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(0 < len, BOX_SELLING_IS_EMPTY);

        let buyer = Signer::address_of(sender);

        let k = 0;
        let exist = false;
        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        while (k < len) {
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
            if (box_sell_info.id == id) {
                exist = true;
                break
            };
            k = k + 1;
        };
        assert(exist, ID_NOT_EXIST);
        assert(1 == box_sell_info.type, TYPE_MISMATCH);
        assert(box_sell_info.selling_price <= Account::balance<PayToken>(buyer), INSUFFICIENT_BALANCE);

        Account::deposit_to_self(sender, Token::withdraw<BoxToken>(&mut box_sell_info.box_tokens, 1));

        let (creator_fee, platform_fee) = get_fee(box_sell_info.selling_price);
        if (0 < creator_fee) {
            Account::deposit<PayToken>(box_selling.creator, Account::withdraw<PayToken>(sender, creator_fee));
        };
        if (0 < platform_fee) {
            Account::deposit<PayToken>(NFT_MARKET_FEE_ADDRESS, Account::withdraw<PayToken>(sender, platform_fee));
        };
        let surplus_amount = box_sell_info.selling_price - creator_fee - platform_fee;
        if (0 < surplus_amount) {
            Account::deposit(box_sell_info.seller, Account::withdraw<PayToken>(sender, surplus_amount));
        };

        Event::emit_event(
            &mut box_selling.buy_events,
            BoxBuyEventV2 {
                id: box_sell_info.id,
                seller: box_sell_info.seller,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                final_price: box_sell_info.selling_price,
                buyer: buyer,
                prev_bidder: @0x1,
                prev_bid_price: 0,
                creator_fee: creator_fee,
                platform_fee: platform_fee
            }
        );

        let remove_box_sell_info = Vector::swap_remove<BoxSellInfoV2<BoxToken, PayToken>>(&mut box_selling.items, k);
        let BoxSellInfoV2<BoxToken, PayToken> {
            id: _,
            type: _,
            seller: _,
            box_tokens,
            selling_price: _,
            bid_tokens,
            bidder: _,
            end_time: _
        } = remove_box_sell_info;
        Token::destroy_zero(box_tokens);
        Token::destroy_zero(bid_tokens);
    }

    public fun box_buy_auction<BoxToken: store, PayToken: store>(sender: &signer, id: u128, price: u128) acquires BoxSellingV2 {
        check_verison(2);
        assert(exists<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        let box_selling = borrow_global_mut<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(len > 0, BOX_SELLING_IS_EMPTY);

        let bidder = Signer::address_of(sender);

        let k = 0;
        let exist = false;
        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        while (k < len) {
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
            if (box_sell_info.id == id) {
                exist = true;
                break
            };
            k = k + 1;
        };
        assert(exist, ID_NOT_EXIST);
        assert(2 == box_sell_info.type, TYPE_MISMATCH);
        assert(price <= Account::balance<PayToken>(bidder), INSUFFICIENT_BALANCE);
        assert((Timestamp::now_milliseconds() as u128) < box_sell_info.end_time, EXPIRED);

        let bid_price = Token::value<PayToken>(&box_sell_info.bid_tokens);
        assert(bid_price < price, PRICE_TOO_LOW);
        if (0 < bid_price) {
            Account::deposit<PayToken>(box_sell_info.bidder, Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, bid_price));
        };

        Token::deposit(&mut box_sell_info.bid_tokens, Account::withdraw<PayToken>(sender, price));
        if ((((Timestamp::now_milliseconds() + MILLISECONDS_5_MIN)) as u128) > box_sell_info.end_time) {
            box_sell_info.end_time = box_sell_info.end_time + (MILLISECONDS_5_MIN as u128);
        };
        let prev_bidder = box_sell_info.bidder;
        box_sell_info.bidder = bidder;

        if (!Account::is_accepts_token<BoxToken>(bidder)) {
            Account::do_accept_token<BoxToken>(sender);
        };

        Event::emit_event(
            &mut box_selling.bid_events,
            BoxBidEventV2 {
                id: box_sell_info.id,
                seller: box_sell_info.seller,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                selling_price: box_sell_info.selling_price,
                bidder: bidder,
                bid_price: price,
                prev_bidder: prev_bidder,
                prev_bid_price: bid_price,
                end_time: box_sell_info.end_time,
            }
        );
    }

    public fun box_delivery<BoxToken: store, PayToken: store>(_sender: &signer, id: u128) acquires BoxSellingV2, Config {
        check_verison(2);
        assert(exists<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        let box_selling = borrow_global_mut<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(0 < len, BOX_SELLING_IS_EMPTY);

        let k = 0;
        let exist = false;
        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        while (k < len) {
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
            if (box_sell_info.id == id) {
                exist = true;
                break
            };
            k = k + 1;
        };
        assert(exist, ID_NOT_EXIST);
        assert(2 == box_sell_info.type, TYPE_MISMATCH);
        assert((Timestamp::now_milliseconds() as u128) > box_sell_info.end_time, UNEXPIRED);
        let bid_price = Token::value<PayToken>(&box_sell_info.bid_tokens);
        let box_token = Token::withdraw<BoxToken>(&mut box_sell_info.box_tokens, 1);
        if (box_sell_info.bidder == @0x1) {
            Account::deposit(box_sell_info.seller, box_token);

            Event::emit_event(
                &mut box_selling.offline_events,
                BoxOfflineEventV2 {
                    id: box_sell_info.id,
                    type: box_sell_info.type,
                    seller: box_sell_info.seller,
                    box_token_code: Token::token_code<BoxToken>(),
                    pay_token_code: Token::token_code<PayToken>(),
                    quantity: 1,
                    selling_price: box_sell_info.selling_price,
                    bidder: box_sell_info.bidder,
                    bid_price: bid_price
                }
            );
        }else {
            Account::deposit(box_sell_info.bidder, box_token);
            let (creator_fee, platform_fee) = get_fee(bid_price);
            if (0 < creator_fee) {
                Account::deposit(box_selling.creator, Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, creator_fee));
            };
            if (0 < platform_fee) {
                Account::deposit(NFT_MARKET_FEE_ADDRESS, Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, platform_fee));
            };
            let surplus_amount = bid_price - creator_fee - platform_fee;
            if (0 < surplus_amount) {
                Account::deposit(box_sell_info.seller, Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, surplus_amount));
            };
            
            Event::emit_event(
                &mut box_selling.accept_bid_events,
                BoxAcceptBidEventV2 {
                    id: box_sell_info.id,
                    seller: box_sell_info.seller,
                    box_token_code: Token::token_code<BoxToken>(),
                    pay_token_code: Token::token_code<PayToken>(),
                    quantity: 1,
                    selling_price: box_sell_info.selling_price,
                    final_price: bid_price,
                    bidder: box_sell_info.bidder,
                    creator_fee: creator_fee,
                    platform_fee: platform_fee
                }
            );
        };

        let remove_box_sell_info = Vector::swap_remove<BoxSellInfoV2<BoxToken, PayToken>>(&mut box_selling.items, k);
        let BoxSellInfoV2<BoxToken, PayToken> {
            id: _,
            type: _,
            seller: _,
            box_tokens,
            selling_price: _,
            bid_tokens,
            bidder: _,
            end_time: _
        } = remove_box_sell_info;
        Token::destroy_zero(box_tokens);
        Token::destroy_zero(bid_tokens);
    }

    public fun box_accept_bid_v2<BoxToken: store, PayToken: store>(sender: &signer, id: u128) acquires BoxSellingV2, Config {
        check_verison(2);
        assert(exists<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        let box_selling = borrow_global_mut<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(0 < len, BOX_SELLING_IS_EMPTY);

        let seller = Signer::address_of(sender);

        let k = 0;
        let exist = false;
        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        while (k < len) {
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
            if (box_sell_info.id == id) {
                exist = true;
                break
            };
            k = k + 1;
        };
        assert(exist, ID_NOT_EXIST);
        assert(2 == box_sell_info.type, TYPE_MISMATCH);
        assert((Timestamp::now_milliseconds() as u128) < box_sell_info.end_time, EXPIRED);
        assert(box_sell_info.seller == seller, PERMISSION_DENIED);

        let box_token = Token::withdraw<BoxToken>(&mut box_sell_info.box_tokens, 1);
        Account::deposit(box_sell_info.bidder, box_token);

        let bid_amount = Token::value<PayToken>(&box_sell_info.bid_tokens);
        assert(0 < bid_amount, PRICE_TOO_LOW);
        let (creator_fee, platform_fee) = get_fee(bid_amount);
        if (0 < creator_fee) {
            let bid_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, creator_fee);
            Account::deposit<PayToken>(box_selling.creator, bid_token);
        };
        if (0 < platform_fee) {
            let bid_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, platform_fee);
            Account::deposit<PayToken>(NFT_MARKET_FEE_ADDRESS, bid_token);
        };
        let surplus_amount = bid_amount - creator_fee - platform_fee;
        if (0 < surplus_amount) {
            let bid_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, surplus_amount);
            Account::deposit(seller, bid_token);
        };

        Event::emit_event(
            &mut box_selling.accept_bid_events,
            BoxAcceptBidEventV2 {
                id: box_sell_info.id,
                seller: box_sell_info.seller,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                selling_price: box_sell_info.selling_price,
                final_price: bid_amount,
                bidder: box_sell_info.bidder,
                creator_fee: creator_fee,
                platform_fee: platform_fee
            }
        );

        let remove_box_sell_info = Vector::swap_remove<BoxSellInfoV2<BoxToken, PayToken>>(&mut box_selling.items, k);
        let BoxSellInfoV2<BoxToken, PayToken> {
            id: _,
            type: _,
            seller: _,
            box_tokens,
            selling_price: _,
            bid_tokens,
            bidder: _,
            end_time: _
        } = remove_box_sell_info;
        Token::destroy_zero(box_tokens);
        Token::destroy_zero(bid_tokens);
    }

    public fun box_offline_v2<BoxToken: store, PayToken: store>(sender: &signer, id: u128) acquires BoxSellingV2 {
        check_verison(2);
        assert(exists<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS), BOX_SELLING_NOT_EXIST);
        let box_selling = borrow_global_mut<BoxSellingV2<BoxToken, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&box_selling.items);
        assert(0 < len, BOX_SELLING_IS_EMPTY);

        let k = 0;
        let exist = false;
        let box_sell_info = Vector::borrow_mut(&mut box_selling.items, 0);
        while (k < len) {
            box_sell_info = Vector::borrow_mut(&mut box_selling.items, k);
            if (box_sell_info.id == id) {
                exist = true;
                break
            };
            k = k + 1;
        };
        assert(exist, ID_NOT_EXIST);
        if (2 == box_sell_info.type) {
            assert((Timestamp::now_milliseconds() as u128) < box_sell_info.end_time, EXPIRED);
        };
        assert(box_sell_info.seller == Signer::address_of(sender), PERMISSION_DENIED);

        let bid_amount = Token::value<PayToken>(&box_sell_info.bid_tokens);
        if (0 < bid_amount) {
            let bid_token = Token::withdraw<PayToken>(&mut box_sell_info.bid_tokens, bid_amount);
            Account::deposit(box_sell_info.bidder, bid_token);
        };
        
        let box_token = Token::withdraw<BoxToken>(&mut box_sell_info.box_tokens, 1);
        Account::deposit(box_sell_info.seller, box_token);
        
        Event::emit_event(
            &mut box_selling.offline_events,
            BoxOfflineEventV2 {
                id: box_sell_info.id,
                type: box_sell_info.type,
                seller: box_sell_info.seller,
                box_token_code: Token::token_code<BoxToken>(),
                pay_token_code: Token::token_code<PayToken>(),
                quantity: 1,
                selling_price: box_sell_info.selling_price,
                bidder: box_sell_info.bidder,
                bid_price: bid_amount
            }
        );
        
        let remove_box_sell_info = Vector::remove<BoxSellInfoV2<BoxToken, PayToken>>(&mut box_selling.items, k);
        let BoxSellInfoV2<BoxToken, PayToken> {
            id: _,
            type: _,
            seller: _,
            box_tokens,
            selling_price: _,
            bid_tokens,
            bidder: _,
            end_time: _
        } = remove_box_sell_info;
        Token::destroy_zero(box_tokens);
        Token::destroy_zero(bid_tokens);
    }
    
    // ******************** NFT Transaction ********************
    // NFT selling list
    struct NFTSelling<NFTMeta: store + drop, NFTBody: store + drop, PayToken: store> has key, store {
        // nft selling list
        items: vector<NFTSellInfo<NFTMeta, NFTBody, PayToken>>,
        sell_events: Event::EventHandle<NFTSellEvent<NFTMeta, NFTBody>>,
        change_price_events: Event::EventHandle<NFTChangePriceEvent<NFTMeta, NFTBody>>,
        offline_events: Event::EventHandle<NFTOfflineEvent<NFTMeta, NFTBody>>,
        bid_events: Event::EventHandle<NFTBidEvent<NFTMeta, NFTBody>>,
        buy_events: Event::EventHandle<NFTBuyEvent<NFTMeta, NFTBody>>,
        accept_bid_events: Event::EventHandle<NFTAcceptBidEvent<NFTMeta, NFTBody>>,
    }

    // NFT extra sell info
    struct NFTSellInfo<NFTMeta: store, NFTBody: store, PayToken: store> has store {
        seller: address,
        // nft item
        nft: Option<NFT<NFTMeta, NFTBody>>,
        // nft id
        id: u64,
        // selling price
        selling_price: u128,
        // top price bid tokens
        bid_tokens: Token::Token<PayToken>,
        // buyer address
        bidder: address,
    }

    // NFT sell event
    struct NFTSellEvent<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        selling_price: u128,
    }

    // NFT change price event
    struct NFTChangePriceEvent<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        before_price: u128,
        after_price: u128,
        bid_price: u128,
        bidder: address,
    }

    // NFT offline event
    struct NFTOfflineEvent<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        selling_price: u128,
        bid_price: u128,
        bidder: address,
    }

    // NFT bid event
    struct NFTBidEvent<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        selling_price: u128,
        bid_price: u128,
        bidder: address,
        prev_bid_price: u128,
        prev_bidder: address,
    }

    // NFT buy event
    struct NFTBuyEvent<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        final_price: u128,
        buyer: address,
        prev_bid_price: u128,
        prev_bidder: address,
        creator_fee: u128,
        platform_fee: u128,
    }

    // NFT bid event
    struct NFTAcceptBidEvent<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        selling_price: u128,
        final_price: u128,
        bidder: address,
        creator_fee: u128,
        platform_fee: u128,
    }

    // NFT sell
    public fun nft_sell<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: &signer,
        id: u64,
        selling_price: u128
    ) acquires NFTSelling {
        check_verison(1);
        // NFTSelling exists
        assert(exists<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        assert(selling_price > 0, PRICE_TOO_LOW);

        let nft_selling = borrow_global_mut<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let owner_address = Signer::address_of(account);
        // Withdraw one NFT token from your account
        let option_nft = NFTGallery::withdraw<NFTMeta, NFTBody>(account, id);
        assert(Option::is_some<NFT<NFTMeta, NFTBody>>(&option_nft), ID_NOT_EXIST);
        let nft_sell_info = NFTSellInfo<NFTMeta, NFTBody, PayToken> {
            seller: owner_address,
            nft: option_nft,
            id: id,
            selling_price: selling_price,
            bid_tokens: Token::zero<PayToken>(),
            bidder: @0x1,
        };
        // nft_sell_info add Vector
        Vector::push_back(&mut nft_selling.items, nft_sell_info);
        // accept PayToken
        if (!Account::is_accepts_token<PayToken>(owner_address)){
            Account::do_accept_token<PayToken>(account);
        };
        Event::emit_event(&mut nft_selling.sell_events,
            NFTSellEvent {
                seller: owner_address,
                id: id,
                pay_token_code: Token::token_code<PayToken>(),
                selling_price: selling_price,
            },
        );
    }

    // NFT change price
    public fun nft_change_price<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: &signer,
        id: u64,
        selling_price: u128
    ) acquires NFTSelling {
        check_verison(1);
        // NFTSelling exists
        assert(exists<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        assert(selling_price > 0, PRICE_TOO_LOW);
        // get sell info
        let nft_selling = borrow_global_mut<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&nft_selling.items);
        assert(len > 0, NFT_SELL_INFO_NOT_EXISTS);
        let nft_sell_info = Vector::borrow_mut(&mut nft_selling.items, 0);
        let k = 0;
        while (k < len) {
            if (nft_sell_info.id == id) {
                break
            };
            k = k + 1;
            assert(k < len, ID_NOT_EXIST);
            nft_sell_info = Vector::borrow_mut(&mut nft_selling.items, k);
        };

        // check seller
        let user_address = Signer::address_of(account);
        assert(user_address == nft_sell_info.seller, PERMISSION_DENIED);
        // check higher than bid price
        let bid_price = Token::value<PayToken>(&nft_sell_info.bid_tokens);
        if (bid_price > 0) {
            assert(selling_price > bid_price, PRICE_TOO_LOW);
        };
        // change price
        let before_price = nft_sell_info.selling_price;
        nft_sell_info.selling_price = selling_price;
        Event::emit_event(&mut nft_selling.change_price_events,
            NFTChangePriceEvent {
                seller: nft_sell_info.seller,
                id: nft_sell_info.id,
                pay_token_code: Token::token_code<PayToken>(),
                before_price: before_price,
                after_price: selling_price,
                bid_price: bid_price,
                bidder: nft_sell_info.bidder,
            },
        );
    }

    // NFT offline
    public fun nft_offline<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: &signer,
        id: u64,
    ) acquires NFTSelling {
        check_verison(1);
        assert(exists<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        let nft_selling = borrow_global_mut<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let nft_sell_info = find_ntf_sell_info_by_id<NFTMeta, NFTBody, PayToken>(&mut nft_selling.items, id);
        // check seller
        let user_address = Signer::address_of(account);
        assert(user_address == nft_sell_info.seller, PERMISSION_DENIED);
        // give back payToken to bidder
        let bid_amount = Token::value(&nft_sell_info.bid_tokens);
        if (bid_amount > 0) {
            let bid_tokens = Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, bid_amount);
            Account::deposit<PayToken>(nft_sell_info.bidder, bid_tokens);
        };
        // get back NFT
        let nft = Option::extract(&mut nft_sell_info.nft);
        NFTGallery::deposit_to<NFTMeta, NFTBody>(nft_sell_info.seller, nft);
        Event::emit_event(&mut nft_selling.offline_events,
            NFTOfflineEvent {
                seller: nft_sell_info.seller,
                id: nft_sell_info.id,
                pay_token_code: Token::token_code<PayToken>(),
                selling_price: nft_sell_info.selling_price,
                bid_price: bid_amount,
                bidder: nft_sell_info.bidder,
            },
        );
        // destory
        let NFTSellInfo<NFTMeta, NFTBody, PayToken> {
            seller: _,
            nft,
            id: _,
            selling_price: _,
            bid_tokens,
            bidder: _,
        } = nft_sell_info;
        Token::destroy_zero(bid_tokens);
        Option::destroy_none(nft);
    }

    // NFT bid
    public fun nft_bid<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: &signer,
        id: u64,
        price: u128
    ) acquires NFTSelling, Config {
        check_verison(1);
        assert(exists<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        assert(price > 0, PRICE_TOO_LOW);

        let nft_selling = borrow_global_mut<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let nft_sell_info = find_ntf_sell_info_by_id<NFTMeta, NFTBody, PayToken>(&mut nft_selling.items, id);
        //bidder address
        let user_address = Signer::address_of(account);
        if (price >= nft_sell_info.selling_price) {
            f_nft_buy<NFTMeta, NFTBody, PayToken>(account, nft_sell_info);
        } else {
            // get bid token quantity
            let bid_tokens = Token::value(&nft_sell_info.bid_tokens);
            let prev_bidder = nft_sell_info.bidder;
            if (bid_tokens > 0) {
                assert(price > bid_tokens, BID_FAILED);
                // pool deduct token
                let pool_tokens = Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, bid_tokens);
                // pay
                Account::deposit<PayToken>(nft_sell_info.bidder, pool_tokens);
            };

            // Deduct deduction from my account PayToken
            let me_tokens = Account::withdraw<PayToken>(account, price);
            // Go to the pool
            Token::deposit(&mut nft_sell_info.bid_tokens, me_tokens);
            nft_sell_info.bidder = user_address;
            // accept
            NFTGallery::accept<NFTMeta, NFTBody>(account);
            //send NFTBidEvent event
            Event::emit_event(&mut nft_selling.bid_events,
                NFTBidEvent {
                    seller: nft_sell_info.seller,
                    id: id,
                    pay_token_code: Token::token_code<PayToken>(),
                    selling_price: nft_sell_info.selling_price,
                    bid_price: price,
                    bidder: user_address,
                    prev_bid_price: bid_tokens,
                    prev_bidder: prev_bidder,
                }
            );
            // nft_sell_info add Vector
            Vector::push_back(&mut nft_selling.items, nft_sell_info)
        };
    }

    // NFT accept bid
    public fun nft_accept_bid<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: &signer,
        id: u64
    ) acquires NFTSelling, Config {
        check_verison(1);
        let user_address = Signer::address_of(account);
        let nft_selling = borrow_global_mut<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let nft_sell_info = find_ntf_sell_info_by_id<NFTMeta, NFTBody, PayToken>(&mut nft_selling.items, id);
        // check seller
        assert(user_address == nft_sell_info.seller, PERMISSION_DENIED);

        let bid_tokens = Token::value(&nft_sell_info.bid_tokens);
        let nft = Option::extract(&mut nft_sell_info.nft);

        let (creator_fee, platform_fee) = get_fee(bid_tokens);

        let creator_address = NFT::get_creator<NFTMeta, NFTBody>(&nft);
        let creator_fee_token = Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, creator_fee);
        Account::deposit<PayToken>(creator_address, creator_fee_token);

        let platform_fee_token = Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, platform_fee);
        Account::deposit<PayToken>(NFT_MARKET_ADDRESS, platform_fee_token);

        let surplus_amount = bid_tokens - creator_fee - platform_fee;
        let surplus_amount_token = Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, surplus_amount);
        Account::deposit<PayToken>(user_address, surplus_amount_token);

        // nft ransfer to bidder
        NFTGallery::deposit_to<NFTMeta, NFTBody>(nft_sell_info.bidder, nft);

        Event::emit_event(&mut nft_selling.accept_bid_events,
            NFTAcceptBidEvent {
                seller: nft_sell_info.seller,
                id: nft_sell_info.id,
                pay_token_code: Token::token_code<PayToken>(),
                selling_price: nft_sell_info.selling_price,
                final_price: bid_tokens,
                bidder: nft_sell_info.bidder,
                creator_fee: creator_fee,
                platform_fee: platform_fee,
            },
        );

        let NFTSellInfo<NFTMeta, NFTBody, PayToken> {
            seller: _,
            nft,
            id: _,
            selling_price: _,
            bid_tokens,
            bidder: _,
        } = nft_sell_info;
        Token::destroy_zero(bid_tokens);
        Option::destroy_none(nft);
    }

    // NFT buy
    public fun nft_buy<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: &signer,
        id: u64
    ) acquires NFTSelling, Config {
        check_verison(1);
        let nft_selling = borrow_global_mut<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let nft_sell_info = find_ntf_sell_info_by_id<NFTMeta, NFTBody, PayToken>(&mut nft_selling.items, id);
        f_nft_buy<NFTMeta, NFTBody, PayToken>(account, nft_sell_info);
    }

    // NFT buy private
    fun f_nft_buy<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: &signer,
        nft_sell_info: NFTSellInfo<NFTMeta, NFTBody, PayToken>,
    ) acquires NFTSelling, Config {
        let user_address = Signer::address_of(account);
        let nft_selling = borrow_global_mut<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let selling_price = nft_sell_info.selling_price;
        let token_balance = Account::balance<PayToken>(user_address);
        assert(token_balance >= selling_price, INSUFFICIENT_BALANCE);
        let nft = Option::extract(&mut nft_sell_info.nft);

        let (creator_fee, platform_fee) = get_fee(selling_price);

        let creator_address = NFT::get_creator<NFTMeta, NFTBody>(&nft);
        let creator_fee_token = Account::withdraw<PayToken>(account, creator_fee);
        Account::deposit<PayToken>(creator_address, creator_fee_token);

        let platform_fee_token = Account::withdraw<PayToken>(account, platform_fee);
        Account::deposit<PayToken>(NFT_MARKET_ADDRESS, platform_fee_token);

        let surplus_amount = selling_price - creator_fee - platform_fee;
        let surplus_amount_token = Account::withdraw<PayToken>(account, surplus_amount);
        Account::deposit<PayToken>(nft_sell_info.seller, surplus_amount_token);

        //        let balance_stc = Account::balance<PayToken>(nft_sell_info.seller);
        //        Debug::print<u128>(&balance_stc);

        // accept
        NFTGallery::accept<NFTMeta, NFTBody>(account);
        // nft transer Own
        NFTGallery::deposit<NFTMeta, NFTBody>(account, nft);
        // give back bid token to bidder
        let bid_price = Token::value<PayToken>(&nft_sell_info.bid_tokens);
        if (bid_price > 0u128) {
            let withdraw_bid_token = Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, bid_price);
            Account::deposit<PayToken>(nft_sell_info.bidder, withdraw_bid_token);
        };

        //send NFTSellEvent event
        Event::emit_event(&mut nft_selling.buy_events,
            NFTBuyEvent {
                seller: nft_sell_info.seller,
                id: nft_sell_info.id,
                pay_token_code: Token::token_code<PayToken>(),
                final_price: selling_price,
                buyer: user_address,
                prev_bid_price: bid_price,
                prev_bidder: nft_sell_info.bidder,
                creator_fee: creator_fee,
                platform_fee: platform_fee,
            },
        );
        let NFTSellInfo<NFTMeta, NFTBody, PayToken> {
            seller: _,
            nft,
            id: _,
            selling_price: _,
            bid_tokens,
            bidder: _,
        } = nft_sell_info;
        Token::destroy_zero(bid_tokens);
        Option::destroy_none(nft);
    }

    //get nft_sell_info by id
    fun find_ntf_sell_info_by_id<NFTMeta: copy + store + drop, NFTBody: store, PayToken: store>(
        c: &mut vector<NFTSellInfo<NFTMeta, NFTBody, PayToken>>,
        id: u64): NFTSellInfo<NFTMeta, NFTBody, PayToken> {
        let len = Vector::length(c);
        assert(0 < len, ID_NOT_EXIST);
        let i = len - 1;
        loop {
            let nft_sell_info = Vector::borrow(c, i);
            let nft = Option::borrow(&nft_sell_info.nft);
            if (NFT::get_id(nft) == id) {
                return Vector::swap_remove(c, i)
            };
            assert(0 < i, ID_NOT_EXIST);
            i = i - 1;
        }
    }

    fun find_ntf_sell_info_by_id_v2<NFTMeta: copy + store + drop, NFTBody: store, PayToken: store>(c: &mut vector<NFTSellInfoV2<NFTMeta, NFTBody, PayToken>>, id: u64): NFTSellInfoV2<NFTMeta, NFTBody, PayToken> {
        let len = Vector::length(c);
        assert(0 < len, ID_NOT_EXIST);
        let i = len - 1;
        loop {
            let nft_sell_info = Vector::borrow(c, i);
            let nft = Option::borrow(&nft_sell_info.nft);
            if (NFT::get_id(nft) == id) {
                return Vector::swap_remove(c, i)
            };
            assert(0 < i, ID_NOT_EXIST);
            i = i - 1;
        }

        // let k = 0;
        // let exist = false;
        // let nft_sell_info = Vector::borrow_mut(&mut nft_selling.items, 0);
        // while (k < len) {
        //     nft_sell_info = Vector::borrow_mut(&mut nft_selling.items, k);
        //     if (id == NFT::get_id(Option::borrow(&nft_sell_info.nft))) {
        //         exist = true;
        //         break
        //     };
        //     k = k + 1;
        // };
        // assert(exist, ID_NOT_EXIST);
    }

    public fun nft_offline_all<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, amount: u64)
    acquires NFTSelling
    {
        assert(exists<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), NFT_SELL_INFO_NOT_EXISTS);
        assert(Signer::address_of(sender) == NFT_MARKET_ADDRESS, PERMISSION_DENIED);

        let nft_selling = borrow_global_mut<NFTSelling<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&nft_selling.items);
        let limit = amount;
        if (amount == 0 || amount > len) {
            limit = len;
        };
        let i = 0;
        while(i < limit) {
            let nft_sell_info = Vector::pop_back(&mut nft_selling.items);
            // give back payToken to bidder
            let bid_amount = Token::value(&nft_sell_info.bid_tokens);
            if (bid_amount > 0) {
                let bid_tokens = Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, bid_amount);
                Account::deposit<PayToken>(nft_sell_info.bidder, bid_tokens);
            };
            // get back NFT
            let nft = Option::extract(&mut nft_sell_info.nft);
            NFTGallery::deposit_to<NFTMeta, NFTBody>(nft_sell_info.seller, nft);
            Event::emit_event(&mut nft_selling.offline_events,
                NFTOfflineEvent {
                    seller: nft_sell_info.seller,
                    id: nft_sell_info.id,
                    pay_token_code: Token::token_code<PayToken>(),
                    selling_price: nft_sell_info.selling_price,
                    bid_price: bid_amount,
                    bidder: nft_sell_info.bidder,
                },
            );
            // destory
            let NFTSellInfo<NFTMeta, NFTBody, PayToken> {
                seller: _,
                nft,
                id: _,
                selling_price: _,
                bid_tokens,
                bidder: _,
            } = nft_sell_info;
            Token::destroy_zero(bid_tokens);
            Option::destroy_none(nft);

            i = i + 1;
        }
    }

    // ******************** NFT Transaction V2 ********************
    // NFT selling list
    struct NFTSellingV2<NFTMeta: store + drop, NFTBody: store + drop, PayToken: store> has key, store {
        // nft selling list
        items: vector<NFTSellInfoV2<NFTMeta, NFTBody, PayToken>>,
        sell_events: Event::EventHandle<NFTSellEventV2<NFTMeta, NFTBody>>,
        offline_events: Event::EventHandle<NFTOfflineEventV2<NFTMeta, NFTBody>>,
        bid_events: Event::EventHandle<NFTBidEventV2<NFTMeta, NFTBody>>,
        buy_events: Event::EventHandle<NFTBuyEventV2<NFTMeta, NFTBody>>,
        accept_bid_events: Event::EventHandle<NFTAcceptBidEventV2<NFTMeta, NFTBody>>,
    }

    // NFT extra sell info
    struct NFTSellInfoV2<NFTMeta: store, NFTBody: store, PayToken: store> has store {
        // 1: fixed price, 2: auction
        type: u64,
        seller: address,
        // nft item
        nft: Option<NFT<NFTMeta, NFTBody>>,
        // nft id
        id: u64,
        // selling price
        selling_price: u128,
        // top price bid tokens
        bid_tokens: Token::Token<PayToken>,
        // buyer address
        bidder: address,
        // end time
        end_time: u128,
    }

    // NFT sell event
    struct NFTSellEventV2<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        type: u64,
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        selling_price: u128,
    }

    // NFT offline event
    struct NFTOfflineEventV2<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        type: u64,
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        selling_price: u128,
        bid_price: u128,
        bidder: address,
    }

    // NFT buy event
    struct NFTBuyEventV2<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        final_price: u128,
        buyer: address,
        prev_bid_price: u128,
        prev_bidder: address,
        creator_fee: u128,
        platform_fee: u128,
    }

    // NFT bid event
    struct NFTBidEventV2<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        selling_price: u128,
        bid_price: u128,
        bidder: address,
        prev_bid_price: u128,
        prev_bidder: address,
    }

    // NFT bid event
    struct NFTAcceptBidEventV2<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        selling_price: u128,
        final_price: u128,
        bidder: address,
        creator_fee: u128,
        platform_fee: u128,
    }

    public fun nft_sell_fix_price<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, id: u64, price: u128) acquires NFTSellingV2 {
        check_verison(2);
        assert(exists<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        assert(0 < price, PRICE_TOO_LOW);

        let seller = Signer::address_of(sender);
        let end_time = (Timestamp::now_milliseconds() as u128);
        let option_nft = NFTGallery::withdraw<NFTMeta, NFTBody>(sender, id);
        assert(Option::is_some<NFT<NFTMeta, NFTBody>>(&option_nft), ID_NOT_EXIST);

        let nft_selling = borrow_global_mut<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);        
        Vector::push_back(
            &mut nft_selling.items,
            NFTSellInfoV2<NFTMeta, NFTBody, PayToken> {
                type: 1,
                seller: seller,
                nft: option_nft,
                id: id,
                selling_price: price,
                bid_tokens: Token::zero<PayToken>(),
                bidder: @0x1,
                end_time: end_time
            }
        );

        if (!Account::is_accepts_token<PayToken>(seller)){
            Account::do_accept_token<PayToken>(sender);
        };

        Event::emit_event(&mut nft_selling.sell_events,
            NFTSellEventV2 {
                type: 1,
                seller: seller,
                id: id,
                pay_token_code: Token::token_code<PayToken>(),
                selling_price: price
            },
        );
    }

    public fun nft_sell_auction<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, id: u64, price: u128, end_day: u64) acquires NFTSellingV2 {
        check_verison(2);
        assert(exists<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        assert(0 < price, PRICE_TOO_LOW);
        assert(1 <= end_day && end_day <= 7, AUCTION_DEADLINE_INVALID);

        let seller = Signer::address_of(sender);
        let end_time = ((Timestamp::now_milliseconds() + end_day * MILLISECONDS_DAY) as u128);
        let option_nft = NFTGallery::withdraw<NFTMeta, NFTBody>(sender, id);
        assert(Option::is_some<NFT<NFTMeta, NFTBody>>(&option_nft), ID_NOT_EXIST);

        let nft_selling = borrow_global_mut<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);        
        Vector::push_back(
            &mut nft_selling.items,
            NFTSellInfoV2<NFTMeta, NFTBody, PayToken> {
                type: 2,
                seller: seller,
                nft: option_nft,
                id: id,
                selling_price: price,
                bid_tokens: Token::zero<PayToken>(),
                bidder: @0x1,
                end_time: end_time
            }
        );

        if (!Account::is_accepts_token<PayToken>(seller)){
            Account::do_accept_token<PayToken>(sender);
        };

        Event::emit_event(&mut nft_selling.sell_events,
            NFTSellEventV2 {
                type: 2,
                seller: seller,
                id: id,
                pay_token_code: Token::token_code<PayToken>(),
                selling_price: price,
            },
        );
    }

    public fun nft_sell_auction_v2<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, id: u64, price: u128, timestamp: u64) acquires NFTSellingV2 {
        check_verison(2);
        assert(exists<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        assert(0 < price, PRICE_TOO_LOW);

        let seller = Signer::address_of(sender);
        let end_time = ((Timestamp::now_milliseconds() + timestamp) as u128);
        let option_nft = NFTGallery::withdraw<NFTMeta, NFTBody>(sender, id);
        assert(Option::is_some<NFT<NFTMeta, NFTBody>>(&option_nft), ID_NOT_EXIST);

        let nft_selling = borrow_global_mut<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);        
        Vector::push_back(
            &mut nft_selling.items,
            NFTSellInfoV2<NFTMeta, NFTBody, PayToken> {
                type: 2,
                seller: seller,
                nft: option_nft,
                id: id,
                selling_price: price,
                bid_tokens: Token::zero<PayToken>(),
                bidder: @0x1,
                end_time: end_time
            }
        );

        if (!Account::is_accepts_token<PayToken>(seller)){
            Account::do_accept_token<PayToken>(sender);
        };

        Event::emit_event(&mut nft_selling.sell_events,
            NFTSellEventV2 {
                type: 2,
                seller: seller,
                id: id,
                pay_token_code: Token::token_code<PayToken>(),
                selling_price: price,
            },
        );
    }

    public fun nft_buy_fix_price<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, id: u64) acquires NFTSellingV2, Config {
        check_verison(2);
        assert(exists<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        let nft_selling = borrow_global_mut<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&nft_selling.items);
        assert(0 < len, BOX_SELLING_IS_EMPTY);

        let buyer = Signer::address_of(sender);
        
        let nft_sell_info = find_ntf_sell_info_by_id_v2<NFTMeta, NFTBody, PayToken>(&mut nft_selling.items, id);
        assert(1 == nft_sell_info.type, TYPE_MISMATCH);
        assert(nft_sell_info.selling_price <= Account::balance<PayToken>(buyer), INSUFFICIENT_BALANCE);
        let nft_ = Option::extract(&mut nft_sell_info.nft);
        
        let (creator_fee, platform_fee) = get_fee(nft_sell_info.selling_price);
        if (0 < creator_fee) {
            let creator_address = NFT::get_creator<NFTMeta, NFTBody>(&nft_);
            Account::deposit<PayToken>(creator_address, Account::withdraw<PayToken>(sender, creator_fee));
        };
        if (0 < platform_fee) {
            Account::deposit<PayToken>(NFT_MARKET_FEE_ADDRESS, Account::withdraw<PayToken>(sender, platform_fee));
        };
        let surplus_amount = nft_sell_info.selling_price - creator_fee - platform_fee;
        if (0 < surplus_amount) {
            Account::deposit<PayToken>(nft_sell_info.seller, Account::withdraw<PayToken>(sender, surplus_amount));
        };

        NFTGallery::accept<NFTMeta, NFTBody>(sender);
        NFTGallery::deposit<NFTMeta, NFTBody>(sender, nft_);

        Event::emit_event(&mut nft_selling.buy_events,
            NFTBuyEventV2 {
                seller: nft_sell_info.seller,
                id: nft_sell_info.id,
                pay_token_code: Token::token_code<PayToken>(),
                final_price: nft_sell_info.selling_price,
                buyer: buyer,
                prev_bidder: @0x1,
                prev_bid_price: 0,                
                creator_fee: creator_fee,
                platform_fee: platform_fee,
            },
        );
        let NFTSellInfoV2<NFTMeta, NFTBody, PayToken> {
            type: _,
            seller: _,
            nft,
            id: _,
            selling_price: _,
            bid_tokens,
            bidder: _,
            end_time: _
        } = nft_sell_info;
        Option::destroy_none(nft);
        Token::destroy_zero(bid_tokens);
    }

    public fun nft_buy_auction<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, id: u64, price: u128) acquires NFTSellingV2 {
        check_verison(2);
        assert(exists<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        let nft_selling = borrow_global_mut<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&nft_selling.items);
        assert(0 < len, BOX_SELLING_IS_EMPTY);

        let bidder = Signer::address_of(sender);
        
        let k = 0;
        let exist = false;
        let nft_sell_info = Vector::borrow_mut(&mut nft_selling.items, 0);
        while (k < len) {
            nft_sell_info = Vector::borrow_mut(&mut nft_selling.items, k);
            if (NFT::get_id(Option::borrow(&nft_sell_info.nft)) == id) {
                exist = true;
                break
            };        
            k = k + 1;
        };
        assert(exist, ID_NOT_EXIST);
        assert(2 == nft_sell_info.type, TYPE_MISMATCH);
        assert(price <= Account::balance<PayToken>(bidder), INSUFFICIENT_BALANCE);
        assert((Timestamp::now_milliseconds() as u128) < nft_sell_info.end_time, EXPIRED);

        let bid_price = Token::value<PayToken>(&nft_sell_info.bid_tokens);
        assert(bid_price < price, PRICE_TOO_LOW);
        if (0 < bid_price) {
            Account::deposit<PayToken>(nft_sell_info.bidder, Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, bid_price));
        };

        Token::deposit(&mut nft_sell_info.bid_tokens, Account::withdraw<PayToken>(sender, price));
        if (nft_sell_info.end_time < ((MILLISECONDS_5_MIN + Timestamp::now_milliseconds()) as u128)) {
            nft_sell_info.end_time = nft_sell_info.end_time + (MILLISECONDS_5_MIN as u128);
        };
        let prev_bidder = nft_sell_info.bidder;
        nft_sell_info.bidder = bidder;

        if (!NFTGallery::is_accept<NFTMeta, NFTBody>(bidder)) {
            NFTGallery::accept<NFTMeta, NFTBody>(sender);
        };
        
        Event::emit_event(
            &mut nft_selling.bid_events,
            NFTBidEventV2 {
                seller: nft_sell_info.seller,
                id: nft_sell_info.id,
                pay_token_code: Token::token_code<PayToken>(),
                selling_price: nft_sell_info.selling_price,
                bidder: bidder,
                bid_price: price,
                prev_bidder: prev_bidder,
                prev_bid_price: bid_price
            }
        );
    }    

    public fun nft_delivery<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(_sender: &signer, id: u64) acquires NFTSellingV2, Config {
        check_verison(2);
        assert(exists<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        let nft_selling = borrow_global_mut<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&nft_selling.items);
        assert(0 < len, BOX_SELLING_IS_EMPTY);

        let nft_sell_info = find_ntf_sell_info_by_id_v2<NFTMeta, NFTBody, PayToken>(&mut nft_selling.items, id);
        assert(2 == nft_sell_info.type, TYPE_MISMATCH);
        assert((Timestamp::now_milliseconds() as u128) > nft_sell_info.end_time, UNEXPIRED);

        let nft_ = Option::extract(&mut nft_sell_info.nft);
        let creator_address = NFT::get_creator<NFTMeta, NFTBody>(&nft_);
        let bid_price = Token::value<PayToken>(&nft_sell_info.bid_tokens);
        if (nft_sell_info.bidder == @0x1) {
            NFTGallery::deposit_to<NFTMeta, NFTBody>(nft_sell_info.seller, nft_);

            Event::emit_event(
                &mut nft_selling.offline_events,
                NFTOfflineEventV2 {
                    type: nft_sell_info.type,
                    seller: nft_sell_info.seller,
                    id: nft_sell_info.id,
                    pay_token_code: Token::token_code<PayToken>(),
                    selling_price: nft_sell_info.selling_price,
                    bidder: nft_sell_info.bidder,
                    bid_price: bid_price
                }
            );
        }else {
            NFTGallery::deposit_to<NFTMeta, NFTBody>(nft_sell_info.bidder, nft_);
            let (creator_fee, platform_fee) = get_fee(bid_price);
            if (0 < creator_fee) {
                Account::deposit<PayToken>(creator_address, Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, creator_fee));
            };
            if (0 < platform_fee) {
                Account::deposit<PayToken>(NFT_MARKET_ADDRESS, Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, platform_fee));
            };
            let surplus_amount = bid_price - creator_fee - platform_fee;
            if (0 < surplus_amount) {
                Account::deposit<PayToken>(nft_sell_info.seller, Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, surplus_amount));
            };

            Event::emit_event(
                &mut nft_selling.accept_bid_events,
                NFTAcceptBidEventV2 {
                    seller: nft_sell_info.seller,
                    id: nft_sell_info.id,
                    pay_token_code: Token::token_code<PayToken>(),
                    selling_price: nft_sell_info.selling_price,
                    final_price: bid_price,
                    bidder: nft_sell_info.bidder,
                    creator_fee: creator_fee,
                    platform_fee: platform_fee
                }
            );
        };

        let NFTSellInfoV2<NFTMeta, NFTBody, PayToken> {
            type: _,
            seller: _,
            nft,
            id: _,
            selling_price: _,
            bid_tokens,
            bidder: _,
            end_time: _
        } = nft_sell_info;
        Option::destroy_none(nft);
        Token::destroy_zero(bid_tokens);
    }

    public fun nft_accept_bid_v2<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, id: u64) acquires NFTSellingV2, Config {
        check_verison(2);
        assert(exists<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        let nft_selling = borrow_global_mut<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&nft_selling.items);
        assert(0 < len, BOX_SELLING_IS_EMPTY);

        let seller = Signer::address_of(sender);

        let nft_sell_info = find_ntf_sell_info_by_id_v2<NFTMeta, NFTBody, PayToken>(&mut nft_selling.items, id);
        assert(2 == nft_sell_info.type, TYPE_MISMATCH);
        assert((Timestamp::now_milliseconds() as u128) < nft_sell_info.end_time, EXPIRED);
        assert(nft_sell_info.seller == seller, PERMISSION_DENIED);

        let nft_ = Option::extract(&mut nft_sell_info.nft);
        let creator_address = NFT::get_creator<NFTMeta, NFTBody>(&nft_);
        NFTGallery::deposit_to<NFTMeta, NFTBody>(nft_sell_info.bidder, nft_);

        let bid_amount = Token::value<PayToken>(&nft_sell_info.bid_tokens);
        assert(0 < bid_amount, PRICE_TOO_LOW);
        let (creator_fee, platform_fee) = get_fee(bid_amount);
        if (0 < creator_fee) {
            Account::deposit<PayToken>(creator_address, Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, creator_fee));
        };
        if (0 < platform_fee) {
            Account::deposit<PayToken>(NFT_MARKET_ADDRESS, Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, platform_fee));
        };
        let surplus_amount = bid_amount - creator_fee - platform_fee;
        if (0 < surplus_amount) {
            Account::deposit(seller, Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, surplus_amount));
        };

        Event::emit_event(
            &mut nft_selling.accept_bid_events,
            NFTAcceptBidEventV2 {
                seller: nft_sell_info.seller,
                id: nft_sell_info.id,
                pay_token_code: Token::token_code<PayToken>(),
                selling_price: nft_sell_info.selling_price,
                final_price: bid_amount,
                bidder: nft_sell_info.bidder,
                creator_fee: creator_fee,
                platform_fee: platform_fee
            }
        );

        let NFTSellInfoV2<NFTMeta, NFTBody, PayToken> {
            type: _,
            seller: _,
            nft,
            id: _,
            selling_price: _,
            bid_tokens,
            bidder: _,
            end_time: _
        } = nft_sell_info;
        Option::destroy_none(nft);
        Token::destroy_zero(bid_tokens);
    }

    public fun nft_offline_v2<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, id: u64) acquires NFTSellingV2 {
        check_verison(2);
        assert(exists<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS), OFFERING_NOT_EXISTS);
        let nft_selling = borrow_global_mut<NFTSellingV2<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let len = Vector::length(&nft_selling.items);
        assert(0 < len, BOX_SELLING_IS_EMPTY);
        
        let seller = Signer::address_of(sender);

        let nft_sell_info = find_ntf_sell_info_by_id_v2<NFTMeta, NFTBody, PayToken>(&mut nft_selling.items, id);
        if (2 == nft_sell_info.type) {
            assert((Timestamp::now_milliseconds() as u128) < nft_sell_info.end_time, EXPIRED);
        };
        assert(nft_sell_info.seller == seller, PERMISSION_DENIED);

        let bid_amount = Token::value<PayToken>(&nft_sell_info.bid_tokens);
        if (0 < bid_amount) {
            Account::deposit(nft_sell_info.bidder, Token::withdraw<PayToken>(&mut nft_sell_info.bid_tokens, bid_amount));
        };
        
        let nft_ = Option::extract(&mut nft_sell_info.nft);
        NFTGallery::deposit_to<NFTMeta, NFTBody>(nft_sell_info.seller, nft_);
        
        Event::emit_event(
            &mut nft_selling.offline_events,
            NFTOfflineEventV2 {
                type: nft_sell_info.type,
                seller: nft_sell_info.seller,
                id: nft_sell_info.id,
                pay_token_code: Token::token_code<PayToken>(),
                selling_price: nft_sell_info.selling_price,
                bidder: nft_sell_info.bidder,
                bid_price: bid_amount
            }
        );

        let NFTSellInfoV2<NFTMeta, NFTBody, PayToken> {
            type: _,
            seller: _,
            nft,
            id: _,
            selling_price: _,
            bid_tokens,
            bidder: _,
            end_time: _
        } = nft_sell_info;
        Option::destroy_none(nft);
        Token::destroy_zero(bid_tokens);
    }

    // ******************** Platform Buyback ********************
    // NFT buy back list
    struct NFTBuyBack<NFTMeta: store + drop, NFTBody: store + drop, PayToken: store> has key, store {
        // nft buying list
        items: vector<NFTBuyBackInfo<NFTMeta, NFTBody, PayToken>>,
        sell_events: Event::EventHandle<NFTBuyBackSellEvent<NFTMeta, NFTBody>>,
    }

    // NFT Commodity information, used to encapsulate NFT
    struct NFTBuyBackInfo<NFTMeta: store, NFTBody: store, PayToken: store> has store {
        id: u64,
        pay_tokens: Token::Token<PayToken>,
    }

    // NFT repurchase sale event
    struct NFTBuyBackSellEvent<NFTMeta: store + drop, NFTBody: store + drop> has drop, store {
        seller: address,
        id: u64,
        pay_token_code: Token::TokenCode,
        final_price: u128,
        buyer: address,
    }

    public fun init_buy_back_list<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer) {
        let sender_address = Signer::address_of(sender);
        assert(sender_address == NFT_MARKET_ADDRESS, PERMISSION_DENIED);

        if (!exists<NFTBuyBack<NFTMeta, NFTBody, PayToken>>(Signer::address_of(sender))) {
            move_to(sender, NFTBuyBack<NFTMeta, NFTBody, PayToken> {
                items: Vector::empty(),
                sell_events: Event::new_event_handle<NFTBuyBackSellEvent<NFTMeta, NFTBody>>(sender),
            });
        };
        if (!NFTGallery::is_accept<NFTMeta, NFTBody>(sender_address)) {
            NFTGallery::accept<NFTMeta, NFTBody>(sender);
        };
    }

    //NFT repurchase
    public fun nft_buy_back<NFTMeta: store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, id: u64, amount: u128) acquires NFTBuyBack {
        let sender_address = Signer::address_of(sender);
        assert(sender_address == NFT_MARKET_ADDRESS, PERMISSION_DENIED);
        let buyBackList = borrow_global_mut<NFTBuyBack<NFTMeta, NFTBody, PayToken>>(sender_address);

        let pay_tokens = Account::withdraw<PayToken>(sender, amount);
        let nft_buy_back_info = NFTBuyBackInfo<NFTMeta, NFTBody, PayToken> {
            id,
            pay_tokens
        };
        Vector::push_back<NFTBuyBackInfo<NFTMeta, NFTBody, PayToken>>(&mut buyBackList.items, nft_buy_back_info);
    }

    // NFT repurchase and sale
    public fun nft_buy_back_sell<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: &signer, id: u64) acquires NFTBuyBack {
        let sender_address = Signer::address_of(sender);
        assert(NFTGallery::is_accept<NFTMeta, NFTBody>(sender_address), ID_NOT_EXIST);

        let buyBackList = borrow_global_mut<NFTBuyBack<NFTMeta, NFTBody, PayToken>>(NFT_MARKET_ADDRESS);
        let NFTBuyBackInfo { id: _, pay_tokens: payTokens } = pop_ntf_buy_back_info_by_id<NFTMeta, NFTBody, PayToken>(&mut buyBackList.items, id);

        //send NFTBuyBackSellEvent event
        Event::emit_event(&mut buyBackList.sell_events,
            NFTBuyBackSellEvent {
                seller: sender_address,
                id,
                pay_token_code: Token::token_code<PayToken>(),
                final_price: Token::value<PayToken>(&payTokens),
                buyer: NFT_MARKET_ADDRESS,
            },
        );

        Account::deposit_to_self(sender, payTokens);
        NFTGallery::transfer<NFTMeta, NFTBody>(sender, id, NFT_MARKET_ADDRESS);
    }

    fun pop_ntf_buy_back_info_by_id<NFTMeta: store, NFTBody: store, PayToken: store>(c: &mut vector<NFTBuyBackInfo<NFTMeta, NFTBody, PayToken>>, id: u64):
    NFTBuyBackInfo<NFTMeta, NFTBody, PayToken> {
        let len = Vector::length(c);
        assert(len > 0, ID_NOT_EXIST);
        let nftBuyBackInfos = len - 1;
        loop {
            // NFTBuyBackInfo<NFTMeta, NFTBody, PayToken>
            let nftBuyBackInfo = Vector::borrow<NFTBuyBackInfo<NFTMeta, NFTBody, PayToken>>(c, nftBuyBackInfos);
            if (nftBuyBackInfo.id == id) {
                return Vector::swap_remove<NFTBuyBackInfo<NFTMeta, NFTBody, PayToken>>(c, nftBuyBackInfos)
            };
            assert(nftBuyBackInfos > 0, ID_NOT_EXIST);
            nftBuyBackInfos = nftBuyBackInfos - 1;
        }
    }
}
}