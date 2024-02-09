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
    let mut calldata = array![name_, symbol_, decimals_.into()];
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

