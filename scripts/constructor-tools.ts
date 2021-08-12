import { ethers } from "hardhat";

const encodeParams = (dataTypes: any[], data: any[]) => {
    const abiCoder = ethers.utils.defaultAbiCoder
    return abiCoder.encode(dataTypes, data)
}

export function parametrizeInitBytecode(
    constructorTypes: any[],
    constructorArgs: any[],
    contractBytecode: string
) {
    return `${contractBytecode}${encodeParams(constructorTypes, constructorArgs).slice(2,)}`
}

export interface ConstructorArgs<L extends number> {
    types: Array<string> & { length: L };
    args: Array<any> & { length: L };
}
