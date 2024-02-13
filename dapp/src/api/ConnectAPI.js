export const connectWallet = async (dispatch, connect) => {
    try {
      dispatch({ type: "loading" });
      const connection = await connect();
      if (connection && connection.isConnected) {
        const { selectedAddress: address, account } = connection;
        dispatch({
          type: "connectWallet",
          payload: { connection, address, account },
        });
  
        return true;
      }
    } catch (err) {
      console.log(err);
      dispatch({ type: "stopLoading" });
      return false;
    } finally {
      dispatch({ type: "stopLoading" });
    }
  };
  
  export const disconnectWallet = async (dispatch, disconnect) => {
    try {
      dispatch({ type: "loading" });
      await disconnect();
      dispatch({
        type: "disconnectWallet",
      });
  
      return true;
    } catch (err) {
      console.log(err);
      dispatch({ type: "stopLoading" });
      return false;
    } finally {
      dispatch({ type: "stopLoading" });
    }
  };