import { useState } from "react"
import { useConnectWallet } from "../context/ConnectContext";
import BigNumber from "bignumber.js";

function WithdrawPage(){
    const [amount, setAmount] = useState(0)
    const {address, account, bwc_contract, staking_contract} = useConnectWallet()
    async function handleWithdraw(){
            try{
            if(!amount) return null;
             console.log(bwc_contract)
             staking_contract.connect(account);
            await staking_contract.withdraw(new BigNumber(amount).shift(18).toString());
            setAmount(0)
            }catch(err){
             console.log(err.message)
            }
           
    }
    return  <div className="shadow-shadowPrimary mx-auto w-[550px] rounded-[20px] bg-white p-6 text-[#3a3a3a]">
        <h1 className="text-lg font-bold">Withdraw your tokens</h1>
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