import { useEffect, useState } from "react";
import BigNumber from "bignumber.js";
import walletIcon from "../../assets/walletIcon.svg";
import CryptoInput from "../components/CryptoInput";
import DataROw from "../components/DataROw";
import { useConnectWallet } from "../../context/ConnectContext";

function StakeContainer() {
  const [bwcBalance, setBwcBalance] = useState("");
  const [amount, setAmount] = useState(0);
  const {
    address,
    account,
    bwc_contract,
    staking_contract,
    rpc_provider: provider,
  } = useConnectWallet();
  const [isStaking, setIsStaking] = useState(false);

  const getBalance = async () => {
    try {
      const balance = await bwc_contract.balance_of(address);
      const big = new BigNumber(balance).shift(-18).toFixed(2).toString();
      setBwcBalance(big);
    } catch (err) {
      console.log(err.message);
    }
  };

  useEffect(() => {
    getBalance();
  }, [address]);

  async function handleStake() {
    try {
      setIsStaking(true);
      const big = new BigNumber(amount).shift(18).toString();
      bwc_contract.connect(account)
      await  bwc_contract.approve("0x0418c48faa18849a7410844456d829b0393f0e981093f651700cb5ed6cca2700", big)
      staking_contract.connect(account);
      const { transaction_hash: stakeTxHash } =
        await staking_contract.stake(big);
      await provider.waitForTransaction(stakeTxHash);
      setAmount(0);
      await getBalance();
    } catch (err) {
      console.log(err.message);
    } finally {
      setIsStaking(false);
    }
  }

  return (
    <div className="mx-auto w-[550px] rounded-[20px] bg-white p-6 text-[#3a3a3a] shadow-shadowPrimary">
      <div className="mb-[21px] flex items-center justify-between font-medium">
        <h1 className="text-xl">Deposit</h1>
        <div className="flex items-center text-xs">
          <img src={walletIcon} alt="" className="mr-1 h-5 w-5" />
          <h5 className="text-sm">{bwcBalance}</h5>
          <div className="ml-[10px] flex items-center gap-x-[10px]">
            <div
              onClick={() => {
                setAmount(bwcBalance);
              }}
              className="cursor-pointer rounded-[50px] border-[1px] border-solid border-[#c4c4c4] px-[11px] py-[2px]"
            >
              Max
            </div>
            <div
              onClick={() => {
                setAmount(bwcBalance / 2);
              }}
              className="cursor-pointer rounded-[50px] border-[1px] border-solid border-[#c4c4c4] px-[11px] py-[2px]"
            >
              Half
            </div>
          </div>
        </div>
      </div>
      <CryptoInput amount={amount} setAmount={setAmount} balance={bwcBalance} />
      <div className="mt-[21px] flex items-center justify-between text-sm font-medium text-[#3a3a3a]">
        <h3 className="text-black">You will receive</h3>
        <h3>{amount} RBCW</h3>
      </div>
      <button disabled={isStaking}
        className="mt-[48px] w-full disabled:cursor-not-allowed disabled:opacity-90 rounded-[50px] bg-[#430F5D] py-[10px] text-center text-base font-black text-white"
        onClick={handleStake}
      >
        {isStaking ? 'Staking...' : 'Stake'}
      </button>
      <div className="mt-[23px] flex flex-col gap-y-4">
        <DataROw title={"Current price"} value={"1BWC = 1RBWC"} />
      </div>
    </div>
  );
}

export default StakeContainer;
