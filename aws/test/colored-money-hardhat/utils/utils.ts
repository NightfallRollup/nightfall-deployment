import { ethers } from "hardhat";

export const hash = ( input: string ) => {
  let hashedValue = ethers.utils.keccak256( ethers.utils.toUtf8Bytes( input ) );
  return hashedValue;
}