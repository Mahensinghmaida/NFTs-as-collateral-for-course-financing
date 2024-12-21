// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTCollateralLoan {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        address nftAddress;
        uint256 nftTokenId;
        bool repaid;
        bool liquidated;
    }

    address public owner;
    uint256 public loanIdCounter;
    mapping(uint256 => Loan) public loans;

    event LoanCreated(
        uint256 loanId,
        address borrower,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        address nftAddress,
        uint256 nftTokenId
    );

    event LoanRepaid(uint256 loanId);
    event LoanLiquidated(uint256 loanId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createLoan(
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        address nftAddress,
        uint256 nftTokenId
    ) external {
        require(amount > 0, "Loan amount must be greater than zero");
        require(duration > 0, "Loan duration must be greater than zero");
        
        IERC721 nft = IERC721(nftAddress);
        require(
            nft.ownerOf(nftTokenId) == msg.sender,
            "Caller must own the NFT"
        );

        nft.safeTransferFrom(msg.sender, address(this), nftTokenId);

        loans[loanIdCounter] = Loan({
            borrower: msg.sender,
            amount: amount,
            interestRate: interestRate,
            duration: duration,
            nftAddress: nftAddress,
            nftTokenId: nftTokenId,
            repaid: false,
            liquidated: false
        });

        emit LoanCreated(
            loanIdCounter,
            msg.sender,
            amount,
            interestRate,
            duration,
            nftAddress,
            nftTokenId
        );

        loanIdCounter++;
    }

    function repayLoan(uint256 loanId) external payable {
        Loan storage loan = loans[loanId];
        require(msg.sender == loan.borrower, "Only the borrower can repay");
        require(!loan.repaid, "Loan already repaid");
        require(!loan.liquidated, "Loan already liquidated");

        uint256 totalAmountDue = loan.amount + (loan.amount * loan.interestRate) / 100;
        require(msg.value >= totalAmountDue, "Insufficient repayment amount");

        loan.repaid = true;

        IERC721(loan.nftAddress).safeTransferFrom(
            address(this),
            loan.borrower,
            loan.nftTokenId
        );

        payable(owner).transfer(msg.value);

        emit LoanRepaid(loanId);
    }

    function liquidateLoan(uint256 loanId) external onlyOwner {
        Loan storage loan = loans[loanId];
        require(!loan.repaid, "Loan already repaid");
        require(!loan.liquidated, "Loan already liquidated");
        require(
            block.timestamp > loan.duration,
            "Loan duration has not expired"
        );

        loan.liquidated = true;

        IERC721(loan.nftAddress).safeTransferFrom(
            address(this),
            owner,
            loan.nftTokenId
        );

        emit LoanLiquidated(loanId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
