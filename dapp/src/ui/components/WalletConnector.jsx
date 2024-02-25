import { useConnectWallet } from "../../context/ConnectContext";
import { connectWallet, disconnectWallet } from "../../api/ConnectAPI";
import { connect, disconnect } from "get-starknet";


function WalletConnector() {
  const { dispatch, connection } = useConnectWallet();


  async function onConnect() {
    const response = await connectWallet(dispatch, connect);
    if (!response) return;
  }

  async function onDisconnect() {
    await disconnectWallet(dispatch, disconnect);
  }
  return (
    <>
      {connection ? (
        <button
          className="px-6 rounded-[20px] py-3 bg-white font-bold text-sm text-[#121212] cursor-pointer"
          onClick={onDisconnect}
        >
          Disconnect
        </button>
      ) : (
        <button
          className="px-6 rounded-[20px] py-3 bg-white font-bold text-sm text-[#121212] cursor-pointer"
          onClick={onConnect}
        >
          Connect Wallet
        </button>
      )}
    </>

  );
}

export default WalletConnector;
