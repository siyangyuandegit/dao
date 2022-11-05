// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
// FakeNFTMarket interface
interface IFakeNFTMarket{
    function getPrice() external view returns(uint256);
    function available(uint256 _tokenId) external view returns(bool);
    function purchase(uint256 _tokenId) external payable;
}

// CryptoNFT interface
interface ICryptoDevsNFT{
    function balanceOf(address owner) external view returns(uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns(uint256);
}

contract CryptoDevsDAO is Ownable{
    struct Proposal{
        // 要从市场买的nft编号
        uint256 nftTokenId;
        // uinx时间，提案的终止日期
        uint256 deadline;
        // 赞成票数
        uint256 yayVotes;
        // 反对票数
        uint256 nayVotes;
        // 提案是否被执行
        bool executed;
        // holder是否投票
        mapping(uint256 => bool) voters;
    }

    // 提案编号到提案的映射
    mapping(uint256 => Proposal) public proposals;
    // 目前为止的提案
    uint256 public numProposals;
    // 初始化接口
    IFakeNFTMarket nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable{
        nftMarketplace = IFakeNFTMarket(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
        _;
    }

    modifier activeProposalOnly(uint256 proposalIndex){
        require(proposals[proposalIndex].deadline > block.timestamp, "DEADLINE_EXCEEDED");
        _;
    }

    modifier inacticeProposalOnly(uint256 proposalIndex){
        require(proposals[proposalIndex].deadline <= block.timestamp, "DEADLINE_NOT_EXCEEDED");
        require(proposals[proposalIndex].executed == false, "PROPOSAL_ALREADY_EXECUTED");
        _;
    }

    function crateProposal(uint256 _nftTokenId) external nftHolderOnly returns(uint256){
        require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        // 设置提案终止日期
        proposal.deadline = block.timestamp + 5 minutes;
        
        numProposals ++;
        return numProposals - 1;
    }

    enum Vote{
        YAY, // YAY = 0
        NAY // NAY = 1
    }

    function voteOnProposal(uint256 proposalIndex, Vote vote) 
        external 
        nftHolderOnly 
        activeProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];
        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;
        // 计算sender有多少nft，以及有多少nft还没有为该提案投票的
        for (uint256 i = 0; i < voterNFTBalance; i++){
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false){
                numVotes ++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "ALREADY_VOTED");
        if (vote == Vote.YAY){
            proposal.yayVotes += numVotes;
        }else {
            proposal.nayVotes += numVotes;
        }
    }

    function executeProposal(uint256 proposalIndex)
        external
        nftHolderOnly
        inacticeProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

        if (proposal.yayVotes > proposal.nayVotes){
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }
    // owner提走DAO合约中的eth
    function withdrawEther() external onlyOwner{
        payable(owner()).transfer(address(this).balance);
    }
    receive() external payable{}
    fallback() external payable {}
}