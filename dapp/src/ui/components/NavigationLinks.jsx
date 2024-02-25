import NavigationLink from "./NavigationLink";

function NavigationLinks() {
  return (
    <ul className="flex items-center gap-x-[34px] text-sm font-bold text-white">
      <NavigationLink text={"Stake"} to={"/"} />
      <NavigationLink text={"Portfolio"} to={"/portfolio"} />
      <NavigationLink text={"Faucet"} to={"/faucet"} />
      <NavigationLink text={"Withdraw"} to={"/withdraw"} />
    </ul>
  );
}

export default NavigationLinks;
