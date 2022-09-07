address 0x7ed4261b68ddb20158109794bbab3ae7 {
module NFTScripts {

    use 0x7ed4261b68ddb20158109794bbab3ae7::NFTMarket;
    use 0x1::Account;

    // ******************** Config ********************
    
    public(script) fun update_verison(sender: signer, verison: u8) {
        NFTMarket::update_verison(&sender, verison);
    }

    // init    
    public(script) fun init_config(
        sender: signer,
        creator_fee: u128,
        platform_fee: u128
    ) {
        NFTMarket::init_config(&sender, creator_fee, platform_fee);
    }

    public(script) fun update_config(
        sender: signer,
        creator_fee: u128,
        platform_fee: u128
    ) {
        NFTMarket::update_config(&sender, creator_fee, platform_fee);
    }


    // ******************** Other ********************`
    // 1.open fee address
    public(script) fun set_auto_accept_token(sender: signer) {
        Account::set_auto_accept_token(&sender, true);
    }

    // ******************** Initial Offering ********************
    public(script) fun init_market<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: signer,
        creator: address,
    ) {
        NFTMarket::init_market<NFTMeta, NFTBody, BoxToken, PayToken>(&sender, creator);
    }

    // initial offering
    public(script) fun box_initial_offering<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: signer,
        box_amount: u128,
        selling_price: u128,
        selling_time: u64,
        creator: address,
    ) {
        NFTMarket::box_initial_offering<NFTMeta, NFTBody, BoxToken, PayToken>(
            &sender,
            box_amount,
            selling_price,
            selling_time,
            creator,
        );
    }

    public(script) fun box_offering_update<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: signer,
        selling_price: u128,
        selling_time: u64,
    ) {
        NFTMarket::box_offering_update<NFTMeta, NFTBody, BoxToken, PayToken>(
            &sender,
            selling_price,
            selling_time,
        )
    }

    public(script) fun box_buy_from_offering<BoxToken: store, PayToken: store>(sender: signer, quantity: u128) {
        NFTMarket::box_buy_from_offering<BoxToken, PayToken>(&sender, quantity);
    }

    // initial white offering
    public(script) fun box_initial_white_offering<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: signer,
        box_amount: u128,
        selling_price: u128,
        selling_time: u64,
        creator: address,
    ) {
        NFTMarket::box_initial_white_offering<NFTMeta, NFTBody, BoxToken, PayToken>(
            &sender,
            box_amount,
            selling_price,
            selling_time,
            creator,
        );
    }

    public(script) fun box_offering_white_update<NFTMeta: store + drop, NFTBody: store + drop, BoxToken: store, PayToken: store>(
        sender: signer,
        selling_price: u128,
        selling_time: u64,
    ) {
        NFTMarket::box_offering_white_update<NFTMeta, NFTBody, BoxToken, PayToken>(
            &sender,
            selling_price,
            selling_time,
        )
    }

    public(script) fun box_buy_from_white_offering<BoxToken: store, PayToken: store>(sender: signer, quantity: u128, box_offering_token: u64) {
        NFTMarket::box_buy_from_white_offering<BoxToken, PayToken>(&sender, quantity, box_offering_token);
    }

    // ******************** NFT Transaction ********************
    // NFT sell
    public(script) fun nft_sell<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: signer,
        id: u64,
        selling_price: u128
    ) {
        NFTMarket::nft_sell<NFTMeta, NFTBody, PayToken>(&account, id, selling_price);
    }

    public(script) fun nft_change_price<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: signer,
        id: u64,
        selling_price: u128
    ) {
        NFTMarket::nft_change_price<NFTMeta, NFTBody, PayToken>(&account, id, selling_price);
    }

    // NFT offline
    public(script) fun nft_offline<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: signer,
        id: u64,
    ) {
        NFTMarket::nft_offline<NFTMeta, NFTBody, PayToken>(&account, id);
    }

    // NFT bid
    public(script) fun nft_bid<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: signer,
        id: u64,
        bid_price: u128
    ) {
        NFTMarket::nft_bid<NFTMeta, NFTBody, PayToken>(&account, id, bid_price);
    }

    // NFT accept bid
    public(script) fun nft_accept_bid<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: signer,
        id: u64
    ) {
        NFTMarket::nft_accept_bid<NFTMeta, NFTBody, PayToken>(&account, id);
    }

    // NFT buy
    public(script) fun nft_buy<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(
        account: signer,
        id: u64
    ) {
        NFTMarket::nft_buy<NFTMeta, NFTBody, PayToken>(&account, id);
    }

    // ******************** NFT Transaction V2 ********************

    public(script) fun nft_sell_fix_price<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64, price: u128) {
        NFTMarket::nft_sell_fix_price<NFTMeta, NFTBody, PayToken>(&sender, id, price);
    }

    public(script) fun nft_sell_auction<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64, price: u128, end_day: u64) {
        NFTMarket::nft_sell_auction<NFTMeta, NFTBody, PayToken>(&sender, id, price, end_day);
    }

    public(script) fun nft_sell_auction_v2<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64, price: u128, timestamp: u64) {
        NFTMarket::nft_sell_auction_v2<NFTMeta, NFTBody, PayToken>(&sender, id, price, timestamp);
    }

    public(script) fun nft_buy_fix_price<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64) {
        NFTMarket::nft_buy_fix_price<NFTMeta, NFTBody, PayToken>(&sender, id);
    }

    public(script) fun nft_buy_auction<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64, price: u128) {
        NFTMarket::nft_buy_auction<NFTMeta, NFTBody, PayToken>(&sender, id, price);
    }

    public(script) fun nft_delivery<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64) {
        NFTMarket::nft_delivery<NFTMeta, NFTBody, PayToken>(&sender, id);
    }

    public(script) fun nft_accept_bid_v2<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64) {
        NFTMarket::nft_accept_bid_v2<NFTMeta, NFTBody, PayToken>(&sender, id);
    }

    public(script) fun nft_offline_v2<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64) {
        NFTMarket::nft_offline_v2<NFTMeta, NFTBody, PayToken>(&sender, id);
    }

    public(script) fun nft_offline_all<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, amount: u64) {
        NFTMarket::nft_offline_all<NFTMeta, NFTBody, PayToken>(&sender, amount);
    }

    // ******************** Box Transaction ********************
    //box sell
    public(script) fun box_sell<BoxToken: store, PayToken: store>(
        seller: signer,
        selling_price: u128
    ) {
        NFTMarket::box_sell<BoxToken, PayToken>(&seller, selling_price);
    }

    //box change price
    public(script) fun box_change_price<BoxToken: store, PayToken: store>(
        seller: signer,
        id: u128,
        selling_price: u128
    ) {
        NFTMarket::box_change_price<BoxToken, PayToken>(&seller, id, selling_price);
    }

    //box sell
    public(script) fun box_offline<BoxToken: store, PayToken: store>(
        seller: signer,
        id: u128
    ) {
        NFTMarket::box_offline<BoxToken, PayToken>(&seller, id);
    }

    //box accept offer price
    public(script) fun box_accept_bid<BoxToken: store, PayToken: store>(
        seller: signer,
        id: u128
    ) {
        NFTMarket::box_accept_bid<BoxToken, PayToken>(&seller, id);
    }

    //box bid price
    public(script) fun box_bid<BoxToken: store, PayToken: store>(
        buyer: signer,
        id: u128,
        bid_price: u128
    ) {
        NFTMarket::box_bid<BoxToken, PayToken>(&buyer, id, bid_price);
    }

    //box buy
    public(script) fun box_buy<BoxToken: store, PayToken: store>(
        buyer: signer,
        id: u128
    ) {
        NFTMarket::box_buy<BoxToken, PayToken>(&buyer, id);
    }

    // ******************** Box Transaction V2 ********************

    public(script) fun box_sell_fix_price<BoxToken: store, PayToken: store>(sender: signer, price: u128) {
        NFTMarket::box_sell_fix_price<BoxToken, PayToken>(&sender, price);
    }

    public(script) fun box_sell_auction<BoxToken: store, PayToken: store>(sender: signer, price: u128, end_day: u64) {
        NFTMarket::box_sell_auction<BoxToken, PayToken>(&sender, price, end_day);
    }

    public(script) fun box_buy_fix_price<BoxToken: store, PayToken: store>(sender: signer, id: u128) {
        NFTMarket::box_buy_fix_price<BoxToken, PayToken>(&sender, id);
    }

    public(script) fun box_buy_auction<BoxToken: store, PayToken: store>(sender: signer, id: u128, price: u128) {
        NFTMarket::box_buy_auction<BoxToken, PayToken>(&sender, id, price);
    }

    public(script) fun box_delivery<BoxToken: store, PayToken: store>(sender: signer, id: u128) {
        NFTMarket::box_delivery<BoxToken, PayToken>(&sender, id);
    }

    public(script) fun box_accept_bid_v2<BoxToken: store, PayToken: store>(sender: signer, id: u128) {
        NFTMarket::box_accept_bid_v2<BoxToken, PayToken>(&sender, id);
    }

    public(script) fun box_offline_v2<BoxToken: store, PayToken: store>(sender: signer, id: u128) {
        NFTMarket::box_offline_v2<BoxToken, PayToken>(&sender, id);
    }

    public(script) fun box_offline_all<BoxToken: store, PayToken: store>(sender: signer, amount: u64) {
        NFTMarket::box_offline_all<BoxToken, PayToken>(&sender, amount);
    }

    // ******************** Buy Back ********************
    public(script) fun init_buy_back_list<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer) {
        NFTMarket::init_buy_back_list<NFTMeta, NFTBody, PayToken>(&sender);
    }

    public(script) fun nft_buy_back<NFTMeta: store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64, amount: u128) {
        NFTMarket::nft_buy_back<NFTMeta, NFTBody, PayToken>(&sender, id, amount);
    }

    public(script) fun nft_buy_back_sell<NFTMeta: copy + store + drop, NFTBody: store + drop, PayToken: store>(sender: signer, id: u64) {
        NFTMarket::nft_buy_back_sell<NFTMeta, NFTBody, PayToken>(&sender, id);
    }
}
}