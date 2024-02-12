use basic_staking_dapp::bwc_staking_contract::IStakeDispatcherTrait;
use basic_staking_dapp::erc20_token::IERC20DispatcherTrait;
use core::result::ResultTrait;
use core::option::OptionTrait;
use basic_staking_dapp::bwc_staking_contract::{IStake, BWCStakingContract, IStakeDispatcher};
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

const bwc_erc_name_: felt252 = 'BWCToken';
const bwc_erc_symbol_: felt252 = 'BWC20';
const bwc_erc_decimals_: u8 = 18_u8;

const receipt_erc_name_: felt252 = 'BWCRewardToken';
const receipt_erc_symbol_: felt252 = 'wBWC20';
const receipt_erc_decimals_: u8 = 18_u8;

const reward_erc_name_: felt252 = 'BWCReceiptToken';
const reward_erc_symbol_: felt252 = 'cBWC20';
const reward_erc_decimals_: u8 = 18_u8;


fn deploy_contract() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    let erc20_contract_class = declare('ERC20');
    let mut bwc_calldata = array![
        bwc_erc_name_, bwc_erc_symbol_, bwc_erc_decimals_.into(), Account::admin().into()
    ];
    let mut receipt_calldata = array![
        receipt_erc_name_,
        receipt_erc_symbol_,
        receipt_erc_decimals_.into(),
        Account::admin().into()
    ];
    let mut reward_calldata = array![
        reward_erc_name_, reward_erc_symbol_, reward_erc_decimals_.into(), Account::admin().into()
    ];

    let bwc_contract_address = erc20_contract_class.deploy(@bwc_calldata).unwrap();
    let receipt_contract_address = erc20_contract_class.deploy(@receipt_calldata).unwrap();
    let reward_contract_address = erc20_contract_class.deploy(@reward_calldata).unwrap();

    let staking_contract_class = declare('BWCStakingContract');
    let mut stake_calldata = array![
        bwc_contract_address.into(), receipt_contract_address.into(), reward_contract_address.into()
    ];

    let staking_contract_address = staking_contract_class.deploy(@stake_calldata).unwrap();
    (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    )
}

#[test]
#[should_panic(expected: ('STAKE: Insufficient funds',))]
fn test_stake_insufficient_funds() {
    let (staking_contract_address, _, _, _) = deploy_contract();
    let dispatcher = IStakeDispatcher { contract_address: staking_contract_address };

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    dispatcher.stake(200);
}

#[test]
#[should_panic(expected: ('STAKE: Low balance',))]
fn test_stake_low_cbwc() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };

    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    stake_dispatcher.stake(30);
}

#[test]
#[should_panic(expected: ('STAKE: Zero amount',))]
fn test_cannot_stake_zero() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };

    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    stake_dispatcher.stake(0);
}


#[test]
#[should_panic(expected: ('STAKE: Amount not allowed',))]
fn test_amount_not_allowed() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };

    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_prank(CheatTarget::One(bwc_contract_address), Account::user1());
    bwc_dispatcher.approve(staking_contract_address, 10);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    stake_dispatcher.stake(14);
}


#[test]
fn test_new_stake_detail_balance() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };

    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_prank(CheatTarget::One(bwc_contract_address), Account::user1());
    bwc_dispatcher.approve(staking_contract_address, 10);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    let prev_stake: u256 = stake_dispatcher.get_stake_balance();
    stake_dispatcher.stake(6);
    assert(stake_dispatcher.get_stake_balance() == (prev_stake + 6), Errors::WRONG_STAKE_BALANCE);
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


/////////////////
//CUSTOM ERRORS
/////////////////
mod Errors {
    const INSUFFICIENT_FUND: felt252 = 'STAKE: Insufficient fund';
    const INSUFFICIENT_BALANCE: felt252 = 'STAKE: Insufficient balance';
    const ADDRESS_ZERO: felt252 = 'STAKE: Address zero';
    const NOT_TOKEN_ADDRESS: felt252 = 'STAKE: Not token address';
    const ZERO_AMOUNT: felt252 = 'STAKE: Zero amount';
    const INSUFFICIENT_FUNDS: felt252 = 'STAKE: Insufficient funds';
    const LOW_CBWCRT_BALANCE: felt252 = 'STAKE: Low balance';
    const NOT_WITHDRAW_TIME: felt252 = 'STAKE: Not yet withdraw time';
    const LOW_CONTRACT_BALANCE: felt252 = 'STAKE: Low contract balance';
    const AMOUNT_NOT_ALLOWED: felt252 = 'STAKE: Amount not allowed';
    const WITHDRAW_AMOUNT_NOT_ALLOWED: felt252 = 'STAKE: Amount not allowed';
    const WRONG_STAKE_BALANCE: felt252 = 'STAKE: Wrong stake balance';
}
