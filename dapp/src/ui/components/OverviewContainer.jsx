import BigNumber from "bignumber.js";
import { useEffect, useState } from "react";
import asset from "../../assets/solanaLogo.png";
import { useNavigate } from "react-router-dom";
import { useConnectWallet } from "../../context/ConnectContext";

function OverviewContainer() {
  const { address, staking_contract } = useConnectWallet();
  const navigate = useNavigate();
  const [stakeBalance, setStakeBalance] = useState("");

  // get_total_stake
  const getBalance = async () => {
    try {
      const balance = await staking_contract.get_stake_balance();
      const big = new BigNumber(balance).shift(-18).toFixed(2).toString();
      setStakeBalance(big);
    } catch (err) {
      console.log(err.message);
    }
  };

  useEffect(() => {
    getBalance();
  }, [address]);
  return (
    <div className="flex items-center justify-between rounded-[10px] bg-white px-[74px] py-[36px] text-black">
      <div className="flex md:gap-x-[60px]">
        <div className="text-center">
          <h2 className="mb-[14px] text-lg font-semibold">Liquidity Staked</h2>
          <h3 className="text-sm font-bold text-[#3a3a3a]">{stakeBalance || "0"} BWC</h3>
        </div>
        <div className="text-center">
          <h2 className="mb-[14px] text-lg font-semibold">Asset</h2>
          <h3 className="flex items-center text-sm font-bold text-[#3a3a3a]">
            <img src={asset} className="mr-1 h-5 w-5" alt="" /> BWC
          </h3>
        </div>
        <div className="text-center">
          <h2 className="mb-[14px] text-lg font-semibold">Duration</h2>
          <h3 className="text-sm font-bold text-[#3a3a3a]">4 mins</h3>
        </div>
        <div className="text-center">
          <h2 className="mb-[14px] text-lg font-semibold">Reward accured</h2>
          <h3 className="text-sm font-bold text-[#3a3a3a]">
            {stakeBalance || "0"} RBWC
          </h3>
        </div>
      </div>
      <button
        className="rounded-[50px] bg-[#430F5D] px-[55px] py-[10px] text-base font-black text-white"
        onClick={() => navigate("/withdraw")}
      >
        Withdraw
      </button>
    </div>
  );
}

export default OverviewContainer;
