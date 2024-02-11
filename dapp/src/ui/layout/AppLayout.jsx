import Navbar from "../components/Navbar";
import { Outlet } from "react-router-dom";
import { useState, useEffect } from "react";
import { connect, disconnect } from "starknetkit";
import { useConnectWallet } from "../../context/ConnectContext";

function AppLayout() {

  const {connection} = useConnectWallet()

  return (
    <div className="flex min-h-[100vh] w-full flex-col bg-mainBg bg-cover bg-center bg-no-repeat pt-[140px]">
      <Navbar
      />
      {connection && <Outlet />}
    </div>
  );
}

export default AppLayout;
