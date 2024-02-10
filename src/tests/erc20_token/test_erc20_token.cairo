use core::option::OptionTrait;
use basic_staking_dapp::erc20_token::IERC20DispatcherTrait;
use basic_staking_dapp::erc20_token::{IERC20, ERC20, IERC20Dispatcher};
use starknet::ContractAddress;
use starknet::contract_address::contract_address_const;
use core::array::ArrayTrait;
use snforge_std::{declare, ContractClassTrait, fs::{FileTrait, read_txt}};
use snforge_std::{start_prank, stop_prank, CheatTarget};
use snforge_std::PrintTrait;
use core::traits::{Into, TryInto};
use starknet::syscalls::deploy_syscall;
use starknet::SyscallResultTrait;

const name_: felt252 = 'BlockheaderToken';
const symbol_: felt252 = 'BHT';
const decimals_: u8 = 18_u8;


fn deploy_contract() -> ContractAddress {
    let erc20contract_class = declare('ERC20');
    let mut calldata = array![name_, symbol_, decimals_.into(), Account::admin().into()];
    let contract_address = erc20contract_class.deploy(@calldata).unwrap();
    contract_address
}


#[test]
fn test_token_name() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };
    let name = dispatcher.get_name();
    assert(name == 'BlockheaderToken', 'name is not correct');
}

#[test]
fn test_decimal_is_correct() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };
    let decimal = dispatcher.get_decimals();

    assert(decimal == 18, 'Decimal is not correct');
}

#[test]
fn test_total_supply() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };
    let total_supply = dispatcher.get_total_supply();

    assert(total_supply == 1000000, 'Total supply is wrong');
}

#[test]
fn test_address_balance() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };
    let balance = dispatcher.get_total_supply();
    let admin_balance = dispatcher.balance_of(Account::admin());
    assert(admin_balance == balance, Errors::INVALID_BALANCE);

    start_prank(CheatTarget::One(contract_address), Account::admin());
    dispatcher.transfer(Account::user1(), 10);
    let new_admin_balance = dispatcher.balance_of(Account::admin());
    new_admin_balance.print();
    assert(new_admin_balance == balance - 10, Errors::INVALID_BALANCE);
    stop_prank(CheatTarget::One(contract_address));

    let user1_balance = dispatcher.balance_of(Account::user1());
    assert(user1_balance == 10, Errors::INVALID_BALANCE);
}

#[test]
fn test_allowance() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };

    start_prank(CheatTarget::One(contract_address), Account::admin());
    dispatcher.approve(contract_address, 10);
    assert(dispatcher.allowance(Account::admin(), contract_address) == 10, Errors::INVALID_BALANCE);
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_transfer() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };
    start_prank(CheatTarget::One(contract_address), Account::admin());
    dispatcher.transfer(Account::user1(), 10);
    let user1_balance = dispatcher.balance_of(Account::user1());
    assert(user1_balance == 10, Errors::INVALID_BALANCE);

    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_transfer_from() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };
    let user1 = Account::user1();
    start_prank(CheatTarget::One(contract_address), Account::admin());
    dispatcher.approve(user1, 10);
    assert(dispatcher.allowance(Account::admin(), user1) == 10, Errors::NOT_ALLOWED);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), user1);
    dispatcher.transfer_from(Account::admin(), Account::user2(), 5);
    assert(dispatcher.balance_of(Account::user2()) == 5, Errors::INVALID_BALANCE);
    // dispatcher.transfer_from(Account::admin(), user1, 15);
    // assert(dispatcher.balance_of(user1) == 5, Errors::INVALID_BALANCE);
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
#[should_panic(expected: ('You have no token approved',))]
fn test_transfer_from_failed_when_not_approved() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };
    start_prank(CheatTarget::One(contract_address), Account::user1());
    dispatcher.transfer_from(Account::admin(), Account::user2(), 5);
}

#[test]
fn test_mint() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };

    let admin = Account::admin();
    let user1 = Account::user1();
    let mint_amount: u256 = 10;

    // Ensure the user1's balance before the mint operation
    let initial_user1_balance = dispatcher.balance_of(Account::user1());
    let initial_total_supply = dispatcher.get_total_supply();

    start_prank(CheatTarget::One(contract_address), Account::admin());
    dispatcher.mint(Account::user1(), mint_amount);

    // Check user1's balance after the mint operation
    assert(
        dispatcher.balance_of(Account::user1()) == initial_user1_balance + mint_amount,
        Errors::INVALID_BALANCE
    );

    // Check the total supply after the mint operation
    assert(
        dispatcher.get_total_supply() == initial_total_supply + mint_amount,
        Errors::UNMATCHED_SUPPLY
    );

    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_burn() {
    let contract_address = deploy_contract();
    let dispatcher = IERC20Dispatcher { contract_address };

    let owner = Account::admin();
    let burn_amount: u256 = 10;

    // Ensure the owner's balance before the burn operation
    let initial_owner_balance = dispatcher.balance_of(owner);
    let initial_total_supply = dispatcher.get_total_supply();

    start_prank(CheatTarget::One(contract_address), owner);
    dispatcher.burn(burn_amount);

    // Check owner's balance after the burn operation
    assert(
        dispatcher.balance_of(owner) == initial_owner_balance - burn_amount, Errors::INVALID_BALANCE
    );

    // Check the total supply after the burn operation
    assert(
        dispatcher.get_total_supply() == initial_total_supply - burn_amount,
        Errors::UNMATCHED_SUPPLY
    );
    stop_prank(CheatTarget::One(contract_address));
}


// Custom errors for error handling
mod Errors {
    const INVALID_DECIMALS: felt252 = 'Invalid decimals!';
    const UNMATCHED_SUPPLY: felt252 = 'Unmatched supply!';
    const INVALID_BALANCE: felt252 = 'Invalid balance!';
    const NOT_ALLOWED: felt252 = 'Invalid allowance given';
    const FUNDS_NOT_SENT: felt252 = 'Funds not sent!';
    const FUNDS_NOT_RECIEVED: felt252 = 'Funds not recieved!';
    const ERROR_INCREASING_ALLOWANCE: felt252 = 'Allowance not increased';
    const ERROR_DECREASING_ALLOWANCE: felt252 = 'Allowance not decreased';
}


mod Account {
    use starknet::ContractAddress;
    use core::traits::TryInto;

    fn user1() -> ContractAddress {
        'joy'.try_into().unwrap()
    }
    fn user2() -> ContractAddress {
        'caleb'.try_into().unwrap()
    }

    fn admin() -> ContractAddress {
        'admin'.try_into().unwrap()
    }
}

