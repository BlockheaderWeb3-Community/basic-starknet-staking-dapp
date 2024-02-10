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


fn deploy_contract() -> (
    ContractAddress, ContractAddress
) {
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

   (staking_contract_address, bwc_contract_address)
}

#[test]
#[should_panic(expected: ('STAKE: Insufficient funds',))]
fn test_stake_insufficient_funds(){
    let (staking_contract_address, _) = deploy_contract();
    let dispatcher = IStakeDispatcher { contract_address: 
    staking_contract_address };

     start_prank(CheatTarget::One(staking_contract_address), Account::user1());
     dispatcher.stake(200);
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
