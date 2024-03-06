import OverviewContainer from "../ui/components/OverviewContainer";
import PortfolioContainer from "../ui/components/PortfolioContainer";

function PortfolioPage() {
  return (
    <div className="px-[80px] pb-[110px] pt-[36px] text-[#3a3a3a]">
      <h1 className="mb-2 text-2xl font-semibold text-white">Portfolio</h1>
      <PortfolioContainer />
    </div>
  );
}

export default PortfolioPage;
