import { useEffect, useState } from "react"
import { useConnectWallet } from "../context/ConnectContext";
import BigNumber from "bignumber.js";
import walletIcon from "../assets/walletIcon.svg";

function WithdrawPage(){
    const [amount, setAmount] = useState(0)
    const {address, account, bwc_contract, staking_contract, receipt_contract, stakingContractAddress} = useConnectWallet()
    const [stakeBalance, setStakeBalance] = useState("");
    const [isWithdrawing, setIsWithdrawing] = useState(false);
  
    const getBalance = async () => {
      try {
        staking_contract.connect(account)
        const balance = await staking_contract.get_stake_balance(account.address);
        const big = new BigNumber(balance).shift(-18).toFixed(2).toString();
        setStakeBalance(big);
      } catch (err) {
        console.log(err.message);
      }
    };
  
    useEffect(() => {
      getBalance();
    }, [address]);
    async function handleWithdraw(){
            try{
            if(!amount) return null;
             console.log(bwc_contract, receipt_contract)
             receipt_contract.connect(account);
             await receipt_contract.approve(stakingContractAddress, new BigNumber(amount).shift(18).toString())
             staking_contract.connect(account);
            await staking_contract.withdraw(new BigNumber(amount).shift(18).toString());
            setAmount(0)
            }catch(err){
             console.log(err.message)
            }
           
    }
    return  <div className="shadow-shadowPrimary mx-auto w-[550px] rounded-[20px] bg-white p-6 text-[#3a3a3a]">
        <div className="mb-[21px] flex items-center justify-between font-medium">
        <h1 className="text-xl">Withdraw</h1>
        <div className="flex items-center text-xs">
          <img src={walletIcon} alt="" className="mr-1 h-5 w-5" />
          <h5 className="text-sm">{stakeBalance}</h5>
          <div className="ml-[10px] flex items-center gap-x-[10px]">
            <div
              onClick={() => {
                setAmount(stakeBalance);
              }}
              className="cursor-pointer rounded-[50px] border-[1px] border-solid border-[#c4c4c4] px-[11px] py-[2px]"
            >
              Max
            </div>
            <div
              onClick={() => {
                setAmount(stakeBalance / 2);
              }}
              className="cursor-pointer rounded-[50px] border-[1px] border-solid border-[#c4c4c4] px-[11px] py-[2px]"
            >
              Half
            </div>
          </div>
        </div>
      </div>
        <input type="number" className="px-4 py-3 border-[#c4c4c4] border-[1px] w-full rounded-lg outline-none mt-3" value={amount} onChange={(e)=>{
            if(e.target.value< 0) {
                setAmount(0)
                return
            }
            setAmount(e.target.value)
        }}/>
        <button className="mt-[24px] w-full rounded-[50px] bg-[#430F5D] py-[10px] text-center text-base font-black text-white" onClick={handleWithdraw}>Withdraw</button>
    </div>
}

export default WithdrawPage