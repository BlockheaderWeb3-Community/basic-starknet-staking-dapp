/* eslint-disable react/prop-types */
import { createContext, useContext, useReducer } from "react";
import { RpcProvider, Contract } from "starknet";
import staking_contract_abi from '../utils/abis/staking_contract_abi.json'
import bwc_token_abi from '../utils/abis/bwc_token_abi.json'
import faucet_abi from '../utils/abis/faucet_abi.json'

const ConnectContext = createContext();

const initialState = {
  connection: null,
  account: null,
  address: null,
  // Loading - status for when connecting or disconnecting
  loading: false,
};

function reducer(state, action) {
  switch (action.type) {
    case "loading":
      return {
        ...state,
        loading: true,
      };

    // stopLaoding - Incase of errors
    case "stopLoading":
      return {
        ...state,
        loading: false,
      };
    case "connectWallet":
      return {
        ...state,
        connection: action.payload.connection,
        account: action.payload.account,
        address: action.payload.address,
        loading: false,
      };
    case "disconnectWallet":
      return {
        ...state,
        connection: null,
        account: null,
        address: null,
        loading: false,
      };
    default:
      throw new Error("Action Unknown");
  }
}

const ConnectProvider = ({ children }) => {
  const [{ connection, account, address, loading }, dispatch] = useReducer(
    reducer,
    initialState,
  );

  const stakingContractAddress =
  "0x55717ee10253162fa9b2ed5fa3f20c8ad2f504ecc60a5bff47c9c7a0bfc0ed6";
  const bwcContractAddress = "0x03ae4482d3273f1e8117335b2985154c4b014e28028c2427ba67452756b61b85"
  const faucetContractAddress = "0x062a32c28e77d7ea584742d2522e9a5d02da4d261b1be4304d5c9b060b5e7533"

const rpc_provider = new RpcProvider({ nodeUrl: 'https://starknet-goerli.g.alchemy.com/v2/cmootBfOhD5Yjs5hTaEY3hf5PlFabEO_' });
const staking_contract = new Contract(staking_contract_abi, stakingContractAddress, rpc_provider)
const bwc_contract = new Contract(bwc_token_abi, bwcContractAddress, rpc_provider)
const faucet_contract = new Contract(faucet_abi, faucetContractAddress, rpc_provider)

  return (
    <ConnectContext.Provider
      value={{
        connection,
        address,
        account,
        dispatch,
        loading,
        rpc_provider,
        staking_contract,
        bwc_contract,
        faucet_contract
      }}
    >
      {children}
    </ConnectContext.Provider>
  );
};

function useConnectWallet() {
  const context = useContext(ConnectContext);
  if (context === undefined)
    throw new Error("Context was read outside the provider scope");

  return context;
}

export { ConnectProvider, useConnectWallet };