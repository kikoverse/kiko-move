address 0x7ed4261b68ddb20158109794bbab3ae7 {
module KikoWhiteList {
    use 0x1::Signer;
    use 0x1::Vector;

    const MANAGER_ADDRESS: address = @0x7ed4261b68ddb20158109794bbab3ae7;

    const PERMISSION_DENIED: u64 = 100001;
    const WHITE_FALSE: u64 = 100002;

    struct KikoWhiteList has key, store {
        items: vector<BoxWihteOffering>
    }

    struct BoxWihteOffering has key, store {
        box_offering_token: u64,
        items: vector<WhiteDetail>
    }
    
    struct WhiteDetail has key, store {
        account: address,
        is_white: u8,
        amount: u8
    }

    fun set_init(sender: &signer) {
        assert(Signer::address_of(sender) == MANAGER_ADDRESS, PERMISSION_DENIED);
        if (!exists<KikoWhiteList>(MANAGER_ADDRESS)) {
            move_to(sender, KikoWhiteList {
                items: Vector::empty()
            });
        };
    }

    fun set_white_list(sender: &signer, box_offering_token: u64, account: address, is_white: u8, amount: u8) acquires KikoWhiteList {
        assert(Signer::address_of(sender) == MANAGER_ADDRESS, PERMISSION_DENIED);
      
        let k = 0;
        let offering_exist = false;
        let white_exist = false;
        let kiko_white_list = borrow_global_mut<KikoWhiteList>(MANAGER_ADDRESS);
        let len = Vector::length(&kiko_white_list.items);
        let m = 0;
        let n = k;
        while (k < len) {
            n = k;
            let box_white_offering = Vector::borrow(&kiko_white_list.items, k);
            if (box_offering_token == box_white_offering.box_offering_token) {
                offering_exist = true;
                let offering_len = Vector::length(&box_white_offering.items);
                while (m < offering_len) {
                    if (account == Vector::borrow(&box_white_offering.items, m).account) {
                        white_exist = true;
                        break
                    };
                    m = m + 1;
                };
                break
            };
            if (white_exist) {
                break
            };
            
            k = k + 1;
        };

        if(offering_exist && white_exist) {
            let box_white_offering = Vector::borrow_mut(&mut kiko_white_list.items, n);
            let white_detail = Vector::borrow_mut(&mut box_white_offering.items, m);
            white_detail.is_white = is_white;
            white_detail.amount = amount;
        }else {
            if (offering_exist) {
                let box_white_offering = Vector::borrow_mut(&mut kiko_white_list.items, n);
                Vector::push_back(
                    &mut box_white_offering.items,
                    WhiteDetail {
                        account: account,
                        is_white: is_white,
                        amount: amount
                    });
            }else{
                let box_white_offering = BoxWihteOffering{
                    box_offering_token: box_offering_token,
                    items:Vector::empty<WhiteDetail>()
                };
                Vector::push_back(&mut box_white_offering.items, 
                    WhiteDetail {
                        account: account,
                        is_white: is_white,
                        amount: amount
                    });
                Vector::push_back(&mut kiko_white_list.items, box_white_offering);
            };
            
        };
    }
    
    fun get_white (account: address, box_offering_token: u64): (u8, u8) acquires KikoWhiteList {
        let kiko_white_list = borrow_global_mut<KikoWhiteList>(MANAGER_ADDRESS);
        let len = Vector::length(&kiko_white_list.items);
        let k = 0;
        let white = 0;
        let amount = 0;
        let white_exist = false;
        while (k < len) {
            let box_white_offering = Vector::borrow(&kiko_white_list.items, k);
            if (box_offering_token == box_white_offering.box_offering_token) {
                let offering_len = Vector::length(&box_white_offering.items);
                let m = 0;
                while (m < offering_len) {
                    if (account == Vector::borrow(&box_white_offering.items, m).account) {
                        white_exist = true;
                        let white_detail = Vector::borrow(&box_white_offering.items, m);
                        white = white_detail.is_white;
                        amount = white_detail.amount;
                        break
                    };
                    m = m + 1;
                };
            };
            if (white_exist) {
                break
            };
            k = k + 1;
        };
        (white, amount)
    }

    public fun update_amount(sender: &signer, box_offering_token: u64, quantity: u8) acquires KikoWhiteList {
        let account = Signer::address_of(sender);
        let kiko_white_list = borrow_global_mut<KikoWhiteList>(MANAGER_ADDRESS);
        let len = Vector::length(&kiko_white_list.items);
        let k = 0;
        let white = 0;
        let white_exist = false;
        while (k < len) {
            let box_white_offering = Vector::borrow_mut(&mut kiko_white_list.items, k);
            if (box_offering_token == box_white_offering.box_offering_token) {
                let offering_len = Vector::length(&box_white_offering.items);
                let m = 0;
                while (m < offering_len) {
                    let white_detail = Vector::borrow_mut(&mut box_white_offering.items, m);
                    if (account == white_detail.account) {
                        white_exist = true;
                        assert(1 == white_detail.is_white && quantity <= white_detail.amount, WHITE_FALSE);
                        white = white_detail.is_white;
                        white_detail.amount = white_detail.amount - quantity;
                        break
                    };
                    m = m + 1;
                };
            };
            if (white_exist) {
                break
            };
            k = k + 1;
        };
        assert(1 == white, WHITE_FALSE);
    }

    public(script) fun f_set_init(sender: signer) {
        set_init(&sender);
    }

    public(script) fun f_set_white_list(sender: signer, box_offering_token: u64, account: address, is_white: u8, amount: u8) acquires KikoWhiteList{
        set_white_list(&sender, box_offering_token, account, is_white, amount);
    }

    public(script) fun f_get_white(account: address, box_offering_token: u64):(u8, u8) acquires KikoWhiteList{
        get_white(account, box_offering_token)
    } 
}
}