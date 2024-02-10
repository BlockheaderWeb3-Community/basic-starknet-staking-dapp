use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;
    fn get_decimals(self: @TContractState) -> u8;
    fn get_total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    );
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: u256);
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: u256
    );
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, amount: u256) -> bool;
}

#[starknet::contract]
mod ERC20 {
    use core::zeroable::Zeroable;
    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: LegacyMap::<ContractAddress, u256>,
        allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
        owner: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    }
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    }


    /////////////////////////
    //CUSTOM ERRORS
    //////////////////////////
    mod Errors {
        const TRANSFER_ADDRESS_ZERO: felt252 = 'Transfer to zero address';
        const OWNER_ADDRESS: felt252 = 'Owner cant be zero address';
        const CALLER_NOT_OWNER: felt252 = 'Caller not owner';
        const ADDRESS_ZERO: felt252 = 'Adddress zero';
        const INSUFFICIENT_FUND: felt252 = 'Insufficient fund';
        const APPROVED_TOKEN: felt252 = 'You have no token approved';
        const AMOUNT_NOT_ALLOWED: felt252 = 'Amount not allowed';
        const MSG_SENDER_NOT_OWNER: felt252 = 'Msg_sender not owner';
        const TRANSFER_FROM_ADDRESS_ZERO: felt252 = 'Transfer from 0';
        const TRANSFER_TO_ADDRESS_ZERO: felt252 = 'Transfer to 0';
        const APPROVE_FROM_ADDRESS_ZERO: felt252 = 'Approve from 0';
        const APPROVE_TO_ADDRESS_ZERO: felt252 = 'Approve to 0';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name_: felt252,
        symbol_: felt252,
        decimals_: u8, // initial_supply: u256,
        // recipient: ContractAddress,
        owner_: ContractAddress
    ) {
        // assert(!recipient.is_zero(), 'ERC20: mint to the 0 address');
        // assert(!owner_.is_zero(), 'ERC20: owner set to 0 address');

        self.name.write(name_);
        self.symbol.write(symbol_);
        self.decimals.write(decimals_);
        self.total_supply.write(1000000);
        self.balances.write(owner_, 1000000);
        self.owner.write(owner_);

        self
            .emit(
                Event::Transfer(
                    Transfer { from: contract_address_const::<0>(), to: owner_, value: 1000000 }
                )
            );
    }


    #[abi(embed_v0)]
    impl IERC20Impl of super::IERC20<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            self.transfer_helper(sender, recipient, amount);
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let caller = get_caller_address();
            let my_allowance = self.allowances.read((sender, caller));

            assert(my_allowance > 0, Errors::APPROVED_TOKEN);
            assert(amount <= my_allowance, Errors::AMOUNT_NOT_ALLOWED);
            self.spend_allowance(sender, caller, amount);
            self.transfer_helper(sender, recipient, amount);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            self.approve_helper(caller, spender, amount);
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller, spender, self.allowances.read((caller, spender)) + added_value
                );
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller, spender, self.allowances.read((caller, spender)) - subtracted_value
                );
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let owner = self.owner.read();
            let caller = get_caller_address();
            assert(owner == caller, Errors::CALLER_NOT_OWNER);
            assert(!recipient.is_zero(), Errors::ADDRESS_ZERO);
            assert(self.balances.read(self.owner.read()) >= amount, Errors::INSUFFICIENT_FUND);
            self
                .balances
                .write(
                    self.owner.read(), self.balances.read(owner) - amount
                ); // subtract amount from caller's balance
            self
                .balances
                .write(
                    recipient, self.balances.read(recipient) + amount
                ); // add amount to recipient's balance
            self.total_supply.write(self.total_supply.read() + amount);
            self
                .emit(
                    Event::Transfer(
                        Transfer {
                            from: contract_address_const::<0>(), to: recipient, value: amount
                        }
                    )
                );
        }

        fn burn(ref self: ContractState, amount: u256) -> bool {
            let owner = self.owner.read();
            let caller = get_caller_address();

            // Check if the caller is the owner.
            assert(owner == caller, Errors::CALLER_NOT_OWNER);

            // Check if the balance of the owner is greater than or equal to the amount to burn.
            assert(self.balances.read(owner) >= amount, Errors::INSUFFICIENT_FUND);

            // Subtract the amount from the owner's balance.
            self.balances.write(owner, self.balances.read(owner) - amount);

            // Update the total supply.
            self.total_supply.write(self.total_supply.read() - amount);

            true
        }
    }

    #[generate_trait]
    impl StorageImpl of StorageTrait {
        fn transfer_helper(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let sender_balance = self.balance_of(sender);

            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            assert(sender_balance >= amount, 'ERC20: sender balance too low');

            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self.allowances.read((owner, spender));
            let ONES_MASK = 0xffffffffffffffffffffffffffffffff_u128;
            let is_unlimited_allowance = current_allowance.low == ONES_MASK
                && current_allowance.high == ONES_MASK;
            if !is_unlimited_allowance {
                self.approve_helper(owner, spender, current_allowance - amount);
            }
        }

        fn approve_helper(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!owner.is_zero(), 'ERC20: approve to zero');
            assert(!spender.is_zero(), 'ERC20: approve from 0');
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }
    }
}
