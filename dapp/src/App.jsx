import "./App.css";
import StakeContainer from "./ui/complex/StakeContainer";

import {
  createBrowserRouter,
  RouterProvider,
  Navigate,
} from "react-router-dom";

// library imports
import { ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

import { AppLayout } from "./ui/layout";
import PortfolioPage from "./pages/PortfolioPage";
import FaucetPage from "./pages/FaucetPage";
import WithdrawPage from "./pages/WithdrawPage";

function App() {
  const router = createBrowserRouter([
    {
      path: "/",
      element: <AppLayout />,
      children: [
        {
          index: true,
          element: <StakeContainer />,
        },
        {
          path: "/withdraw",
          element: <WithdrawPage />,
        },
        {
          path: "/faucet",
          element: <FaucetPage />,
        },
      ],
    },
  ]);

  return (
    <>
      <RouterProvider router={router} />
      <ToastContainer />
    </>
  );
}

export default App;
