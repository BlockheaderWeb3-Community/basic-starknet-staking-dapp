use basic_staking_dapp::{
    bwc_staking_contract::{IStakeDispatcherTrait, IStake, BWCStakingContract, IStakeDispatcher},
    erc20_token::{IERC20DispatcherTrait, IERC20, ERC20, IERC20Dispatcher}
};
use core::{result::ResultTrait, option::OptionTrait, array::ArrayTrait, traits::{Into, TryInto}};
use starknet::{ContractAddress, get_block_timestamp, contract_address::contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, fs::{FileTrait, read_txt}, start_prank, stop_prank, CheatTarget,
    start_warp, PrintTrait, spy_events, SpyOn, EventSpy, EventFetcher, event_name_hash, Event
};


//BWC contract calldata
const bwc_erc_name_: felt252 = 'BWCToken';
const bwc_erc_symbol_: felt252 = 'BWC20';
const bwc_erc_decimals_: u8 = 18_u8;


//Receipt token contract calldata
const receipt_erc_name_: felt252 = 'BWCRewardToken';
const receipt_erc_symbol_: felt252 = 'wBWC20';
const receipt_erc_decimals_: u8 = 18_u8;


//Reward token contract calldata
const reward_erc_name_: felt252 = 'BWCReceiptToken';
const reward_erc_symbol_: felt252 = 'cBWC20';
const reward_erc_decimals_: u8 = 18_u8;


//Deploy helper function to return staking, reward, receipt and bwc contract addresses
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


//Test to see if storage variables were written to well
#[test]
fn test_constructor() {
    let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();

    let staking_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    assert(
        staking_dispatcher.get_bwc_token_address() == bwc_contract_address,
        Errors::CONSTRUCTOR_ERROR
    );
    assert(
        staking_dispatcher.get_receipt_token_address() == receipt_contract_address,
        Errors::CONSTRUCTOR_ERROR
    );
    assert(
        staking_dispatcher.get_reward_token_address() == reward_contract_address,
        Errors::CONSTRUCTOR_ERROR
    );
}


// test that address zero cannot call stake
#[test]
#[should_panic(expected: ('Address zero not allowed',))]
fn test_caller_not_zero() {
    let (staking_contract_address, _, _, _) = deploy_contract();
    let dispatcher = IStakeDispatcher { contract_address: staking_contract_address };

    start_prank(CheatTarget::One(staking_contract_address), Account::zero());
    dispatcher.stake(200);
}


//test that user cannot stake 0
#[test]
#[should_panic(expected: ('Zero amount',))]
fn test_cannot_stake_zero() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    stake_dispatcher.stake(0);
}


//test that stake fails at insufficent tokens
#[test]
#[should_panic(expected: ('STAKE: Insufficient funds',))]
fn test_stake_insufficient_funds() {
    let (staking_contract_address, _, _, _) = deploy_contract();
    let dispatcher = IStakeDispatcher { contract_address: staking_contract_address };

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    dispatcher.stake(200);
}


//Stake should fail when there aren't enough receipt tokens
#[test]
#[should_panic(expected: ('STAKE: Low balance',))]
fn test_stake_low_cbwc() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };

    //user1 is being sent 35 tokens worth of bwc
    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    //the staking contract is being sent 20 receipt tokens
    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    stake_dispatcher.stake(30);
}

// Test stake should fail if user has not approved the staking contract to spend his/her bwc token.
#[test]
#[should_panic(expected: ('STAKE: Amount not allowed',))]
fn test_amount_not_allowed() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };

    //user1 is being sent 35 tokens worth of bwc
    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    //the staking contract is being sent 20 receipt tokens
    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    //user approves staking contract to spend 10 bwc tokens
    start_prank(CheatTarget::One(bwc_contract_address), Account::user1());
    bwc_dispatcher.approve(staking_contract_address, 10);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    //fails because the user only approved for 10 of his tokens to be spent not 14.
    stake_dispatcher.stake(14);
}


//test that stake detail amount updates after stake. 
#[test]
fn test_update_stake_detail_balance() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };

    //user1 is being sent 35 worth of bwc tokens
    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    //staking contract is being sent 20 worth of receipt tokens
    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    //user approves for staking contract to spend 10 of his tokens
    start_prank(CheatTarget::One(bwc_contract_address), Account::user1());
    bwc_dispatcher.approve(staking_contract_address, 10);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    let prev_stake: u256 = stake_dispatcher.get_stake_balance(Account::user1());

    //user1 stakes 6
    stake_dispatcher.stake(6);
    assert(stake_dispatcher.get_stake_balance(Account::user1()) == (prev_stake + 6), Errors::WRONG_STAKE_BALANCE);
}


//Test that bwc tokens have been sent from the staker to the staking contract after staking
#[test]
fn test_transfer_stake_token() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let prev_stake_contract_balance = bwc_dispatcher.balance_of(staking_contract_address);
    let prev_allowance = bwc_dispatcher.allowance(Account::user1(), staking_contract_address);

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
    stake_dispatcher.stake(6);

    assert(
        bwc_dispatcher.allowance(Account::user1(), staking_contract_address) == prev_allowance
            + 10
            - 6,
        Errors::INVALID_ALLOWANCE
    );
    assert(
        bwc_dispatcher.balance_of(staking_contract_address) == prev_stake_contract_balance + 6,
        Errors::INVALID_BALANCE
    );
    stop_prank(CheatTarget::One(staking_contract_address));
}

//test that receipt tokens have been sent to the staker after staking
#[test]
fn test_transfer_receipt_token() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let prev_stake_contract_receipt_token_balance: u256 = receipt_dispatcher
        .balance_of(staking_contract_address);
    let prev_staker_receipt_token_balance: u256 = receipt_dispatcher.balance_of(Account::user1());

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
    stake_dispatcher.stake(6);
    assert(
        receipt_dispatcher.balance_of(Account::user1()) == prev_staker_receipt_token_balance + 6,
        Errors::INVALID_BALANCE
    );
    stop_prank(CheatTarget::One(staking_contract_address));
}


//test that the STAKETOKEN event was fired after staking
#[test]
fn test_token_staked_event_fired() {
    let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_contract_address };

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
    let mut spy = spy_events(SpyOn::One(staking_contract_address));
    stake_dispatcher.stake(6);

    spy.fetch_events();

    assert(spy.events.len() == 1, 'There should be one event');

    let (from, event) = spy.events.at(0);
    assert(from == @staking_contract_address, 'Emitted from wrong address');
    assert(event.keys.at(0) == @event_name_hash('TokenStaked'), 'Wrong event name');
}

#[test]
fn test_get_stake_balance(){
     let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_contract_address };

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
    let mut spy = spy_events(SpyOn::One(staking_contract_address));
    stake_dispatcher.stake(6);
    assert(stake_dispatcher.get_stake_balance(Account::user1()) == 6, 'wrong' );
} 


//test that address zero can not withdraw
#[test]
#[should_panic(expected: ('Address zero not allowed',))]
fn test_withraw_with_addr_zero() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    start_prank(CheatTarget::One(staking_contract_address), Account::zero());
    stake_dispatcher.withdraw(1);
}


//test that zero can not be withdrawn
#[test]
#[should_panic(expected: ('Zero amount',))]
fn test_withraw_with_zero_amount() {
    let (staking_contract_address, bwc_contract_address, receipt_contract_address, _) =
        deploy_contract();
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    stake_dispatcher.withdraw(0);
}

//test that staker can not withdraw more than he staked
#[test]
#[should_panic(expected: ('Withdraw amount not allowed',))]
fn test_invalid_withdrawal_amount() {
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
    stake_dispatcher.stake(6);
    stake_dispatcher.withdraw(30);
}

//test that the staker can not withdraw earlier than the stipulated time frame
#[test]
#[should_panic(expected: ('Not yet time to withdraw',))]
fn test_invalid_withdraw_time() {
    let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_contract_address };

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
    stake_dispatcher.stake(6);
    stake_dispatcher.withdraw(5);
}


//Test that the staking contract has enough reward tokens.
#[test]
#[should_panic(expected: ('Not enough reward token to send',))]
fn test_insufficient_reward_token() {
    let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_contract_address };

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
    stake_dispatcher.stake(6);
    start_warp(CheatTarget::One(staking_contract_address), get_block_timestamp() + 240);
    stake_dispatcher.withdraw(5);
}


//Test that the staking contract has suffient bwc token for withdrawal
#[test]
fn test_sufficient_bwc_token_for_withdraw() {
    let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_contract_address };

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
    stake_dispatcher.stake(6);
    start_warp(CheatTarget::One(staking_contract_address), get_block_timestamp() + 240);
    assert(bwc_dispatcher.balance_of(staking_contract_address) >= 6, Errors::INVALID_BALANCE);
}

//Test for allowance of staker to spend receipt tokens for withdrawal
#[test]
fn test_sufficient_receipt_token_allowance_for_withdraw() {
    let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_contract_address };

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
    stake_dispatcher.stake(6);

    start_prank(CheatTarget::One(receipt_contract_address), Account::user1());
    receipt_dispatcher.approve(staking_contract_address, 6);
    assert(
        receipt_dispatcher.allowance(Account::user1(), staking_contract_address) >= 6,
        Errors::INSUFFICIENT_BALANCE
    );
}


//test withdraw should fail in there is insufficient receipt token allowance
#[test]
#[should_panic(expected: ('receipt tkn allowance too low',))]
fn test_insufficient_receipt_token_allowance_for_withdraw() {
    let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_contract_address };

    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_prank(CheatTarget::One(reward_contract_address), Account::admin());
    reward_dispatcher.transfer(staking_contract_address, 50);
    stop_prank(CheatTarget::One(reward_contract_address));

    start_prank(CheatTarget::One(bwc_contract_address), Account::user1());
    bwc_dispatcher.approve(staking_contract_address, 10);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    stake_dispatcher.stake(6);

    start_warp(CheatTarget::One(staking_contract_address), get_block_timestamp() + 240);
    stake_dispatcher.withdraw(6);
}

//test that tokens have been distributed appropriately after withdrawal
#[test]
fn test_withdraw() {
    let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_contract_address };

    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_prank(CheatTarget::One(reward_contract_address), Account::admin());
    reward_dispatcher.transfer(staking_contract_address, 50);
    stop_prank(CheatTarget::One(reward_contract_address));

    start_prank(CheatTarget::One(bwc_contract_address), Account::user1());
    bwc_dispatcher.approve(staking_contract_address, 10);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    stake_dispatcher.stake(6);

    start_prank(CheatTarget::One(receipt_contract_address), Account::user1());
    receipt_dispatcher.approve(staking_contract_address, 6);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_warp(CheatTarget::One(staking_contract_address), get_block_timestamp() + 240);
    stake_dispatcher.withdraw(6);

    // Test that staker stake balance has been updated
    assert(stake_dispatcher.get_stake_balance(Account::user1()) == 0, Errors::INVALID_BALANCE);

    // Test that receipt tokens have removed from staker balance
    assert(receipt_dispatcher.balance_of(Account::user1()) == 0, Errors::INVALID_BALANCE);

    // Test that reciept tokens have been returned to staking contract
    assert(receipt_dispatcher.balance_of(staking_contract_address) == 20, Errors::INVALID_BALANCE);

    // Test that reward token has been sent to the staker
    assert(reward_dispatcher.balance_of(Account::user1()) == 6, Errors::INVALID_BALANCE);

    // Test that stake token has been sent to the staker
    assert(bwc_dispatcher.balance_of(Account::user1()) == 35, Errors::INVALID_BALANCE);
}

//test that withdraw event was fired after withdrawal
#[test]
fn test_withdraw_event_fired() {
    let (
        staking_contract_address,
        bwc_contract_address,
        receipt_contract_address,
        reward_contract_address
    ) =
        deploy_contract();
    let receipt_dispatcher = IERC20Dispatcher { contract_address: receipt_contract_address };
    let stake_dispatcher = IStakeDispatcher { contract_address: staking_contract_address };
    let bwc_dispatcher = IERC20Dispatcher { contract_address: bwc_contract_address };
    let reward_dispatcher = IERC20Dispatcher { contract_address: reward_contract_address };

    start_prank(CheatTarget::One(bwc_contract_address), Account::admin());
    bwc_dispatcher.transfer(Account::user1(), 35);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(receipt_contract_address), Account::admin());
    receipt_dispatcher.transfer(staking_contract_address, 20);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_prank(CheatTarget::One(reward_contract_address), Account::admin());
    reward_dispatcher.transfer(staking_contract_address, 50);
    stop_prank(CheatTarget::One(reward_contract_address));

    start_prank(CheatTarget::One(bwc_contract_address), Account::user1());
    bwc_dispatcher.approve(staking_contract_address, 10);
    stop_prank(CheatTarget::One(bwc_contract_address));

    start_prank(CheatTarget::One(staking_contract_address), Account::user1());
    stake_dispatcher.stake(6);

    start_prank(CheatTarget::One(receipt_contract_address), Account::user1());
    receipt_dispatcher.approve(staking_contract_address, 6);
    stop_prank(CheatTarget::One(receipt_contract_address));

    start_warp(CheatTarget::One(staking_contract_address), get_block_timestamp() + 240);
    let mut spy = spy_events(SpyOn::One(staking_contract_address));
    stake_dispatcher.withdraw(6);
    spy.fetch_events();

    assert(spy.events.len() == 1, 'There should be one event');

    let (from, event) = spy.events.at(0);
    assert(from == @staking_contract_address, 'Emitted from wrong address');
    assert(event.keys.at(0) == @event_name_hash('TokenWithdraw'), 'Wrong event name');
}


//Sample users
mod Account {
    use core::{option::OptionTrait, traits::TryInto};
    use starknet::ContractAddress;


    fn user1() -> ContractAddress {
        'joy'.try_into().unwrap()
    }
    fn user2() -> ContractAddress {
        'caleb'.try_into().unwrap()
    }

    fn admin() -> ContractAddress {
        'admin'.try_into().unwrap()
    }

    fn zero() -> ContractAddress {
        0x0000000000000000000000000000000000000000.try_into().unwrap()
    }
}


/////////////////
//CUSTOM ERRORS
/////////////////
mod Errors {
    const INSUFFICIENT_FUND: felt252 = 'STAKE: Insufficient fund';
    const INSUFFICIENT_BALANCE: felt252 = 'STAKE: Insufficient balance';
    const ADDRESS_ZERO: felt252 = 'Address zero not allowed';
    const NOT_TOKEN_ADDRESS: felt252 = 'STAKE: Not token address';
    const ZERO_AMOUNT: felt252 = 'Zero amount';
    const INSUFFICIENT_FUNDS: felt252 = 'STAKE: Insufficient funds';
    const LOW_CBWCRT_BALANCE: felt252 = 'STAKE: Low balance';
    const NOT_WITHDRAW_TIME: felt252 = 'STAKE: Not yet withdraw time';
    const LOW_CONTRACT_BALANCE: felt252 = 'STAKE: Low contract balance';
    const AMOUNT_NOT_ALLOWED: felt252 = 'STAKE: Amount not allowed';
    const WITHDRAW_AMOUNT_NOT_ALLOWED: felt252 = 'Withdraw amount not allowed';
    const WRONG_STAKE_BALANCE: felt252 = 'STAKE: Wrong stake balance';
    const INVALID_BALANCE: felt252 = 'Invalid balance';
    const INVALID_ALLOWANCE: felt252 = 'Invalid allowance';
    const CONSTRUCTOR_ERROR: felt252 = 'Constructor error in deployment';
}
