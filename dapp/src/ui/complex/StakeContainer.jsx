import { useEffect, useState } from "react";
import BigNumber from "bignumber.js";
import walletIcon from "../../assets/walletIcon.svg";
import CryptoInput from "../components/CryptoInput";
import DataROw from "../components/DataROw";
import { useConnectWallet } from "../../context/ConnectContext";

function StakeContainer() {
  const [symbol, setSymbol] = useState("");
  const [bwcBalance, setBwcBalance] = useState("");
  const [amount, setAmount] = useState(0);


  // const [provider, address] = useOutletContext();
  const {address, account, bwc_contract, staking_contract} = useConnectWallet()

  const getBalance = async () => {
    try{
     console.log(bwc_contract)
     // bwc_contract.connect(account);
     const balance = await bwc_contract.balance_of(address);
     const big = new BigNumber(balance).shift(-18).toString()
     setBwcBalance(big)
     console.log(big)
    }catch(err){
     console.log(err.message)
    }
   }
   
  useEffect(()=> {
    getBalance()
  }, [address])


  return (
    <div className="shadow-shadowPrimary mx-auto w-[550px] rounded-[20px] bg-white p-6 text-[#3a3a3a]">
      <div className="mb-[21px] flex items-center justify-between font-medium">
        <h1 className="text-xl">Deposit</h1>
        <div className="flex items-center text-xs">
          <img src={walletIcon} alt="" className="mr-1 h-5 w-5" />
          <h5 className="text-sm">
            {bwcBalance}
          </h5>
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
      <CryptoInput
        amount={amount}
        setAmount={setAmount}
        balance={bwcBalance}
      />
      <div className="mt-[21px] flex items-center justify-between text-sm font-medium text-[#3a3a3a]">
        <h3 className="text-black">You will receive</h3>
        <h3>{amount} RBCW</h3>
      </div>
      <button className="mt-[48px] w-full rounded-[50px] bg-[#430F5D] py-[10px] text-center text-base font-black text-white" onClick={async ()=>{
        const big = new BigNumber(amount).shift(18).toString()
        staking_contract.connect(account);
         await staking_contract.stake(big)
         setAmount(0)
         getBalance()
      }}>
        Stake
      </button>
      <div className="mt-[23px] flex flex-col gap-y-4">
        <DataROw title={"Current price"} value={"1BWC = 1RBWC"} />
        <DataROw title={"Commission"} value={"10%"} />
        <DataROw title={"Reward"} value={"200TC"} />
      </div>
    </div>
  );
}

export default StakeContainer;
