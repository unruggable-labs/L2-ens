/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import { FunctionFragment, Result, EventFragment } from "@ethersproject/abi";
import { Listener, Provider } from "@ethersproject/providers";
import { TypedEventFilter, TypedEvent, TypedListener, OnEvent } from "./common";

export interface ABIResolverInterface extends utils.Interface {
  functions: {
    "ABI(bytes32,uint256)": FunctionFragment;
    "clearRecords(bytes32)": FunctionFragment;
    "recordVersions(bytes32)": FunctionFragment;
    "setABI(bytes32,uint256,bytes)": FunctionFragment;
    "supportsInterface(bytes4)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "ABI",
    values: [BytesLike, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "clearRecords",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "recordVersions",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "setABI",
    values: [BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "supportsInterface",
    values: [BytesLike]
  ): string;

  decodeFunctionResult(functionFragment: "ABI", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "clearRecords",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "recordVersions",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "setABI", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "supportsInterface",
    data: BytesLike
  ): Result;

  events: {
    "ABIChanged(bytes32,uint256)": EventFragment;
    "VersionChanged(bytes32,uint64)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "ABIChanged"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "VersionChanged"): EventFragment;
}

export type ABIChangedEvent = TypedEvent<
  [string, BigNumber],
  { node: string; contentType: BigNumber }
>;

export type ABIChangedEventFilter = TypedEventFilter<ABIChangedEvent>;

export type VersionChangedEvent = TypedEvent<
  [string, BigNumber],
  { node: string; newVersion: BigNumber }
>;

export type VersionChangedEventFilter = TypedEventFilter<VersionChangedEvent>;

export interface ABIResolver extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: ABIResolverInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    ABI(
      node: BytesLike,
      contentTypes: BigNumberish,
      overrides?: CallOverrides
    ): Promise<[BigNumber, string]>;

    clearRecords(
      node: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    recordVersions(
      arg0: BytesLike,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    setABI(
      node: BytesLike,
      contentType: BigNumberish,
      data: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    supportsInterface(
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<[boolean]>;
  };

  ABI(
    node: BytesLike,
    contentTypes: BigNumberish,
    overrides?: CallOverrides
  ): Promise<[BigNumber, string]>;

  clearRecords(
    node: BytesLike,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  recordVersions(
    arg0: BytesLike,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  setABI(
    node: BytesLike,
    contentType: BigNumberish,
    data: BytesLike,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  supportsInterface(
    interfaceID: BytesLike,
    overrides?: CallOverrides
  ): Promise<boolean>;

  callStatic: {
    ABI(
      node: BytesLike,
      contentTypes: BigNumberish,
      overrides?: CallOverrides
    ): Promise<[BigNumber, string]>;

    clearRecords(node: BytesLike, overrides?: CallOverrides): Promise<void>;

    recordVersions(
      arg0: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    setABI(
      node: BytesLike,
      contentType: BigNumberish,
      data: BytesLike,
      overrides?: CallOverrides
    ): Promise<void>;

    supportsInterface(
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<boolean>;
  };

  filters: {
    "ABIChanged(bytes32,uint256)"(
      node?: BytesLike | null,
      contentType?: BigNumberish | null
    ): ABIChangedEventFilter;
    ABIChanged(
      node?: BytesLike | null,
      contentType?: BigNumberish | null
    ): ABIChangedEventFilter;

    "VersionChanged(bytes32,uint64)"(
      node?: BytesLike | null,
      newVersion?: null
    ): VersionChangedEventFilter;
    VersionChanged(
      node?: BytesLike | null,
      newVersion?: null
    ): VersionChangedEventFilter;
  };

  estimateGas: {
    ABI(
      node: BytesLike,
      contentTypes: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    clearRecords(
      node: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    recordVersions(
      arg0: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    setABI(
      node: BytesLike,
      contentType: BigNumberish,
      data: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    supportsInterface(
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    ABI(
      node: BytesLike,
      contentTypes: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    clearRecords(
      node: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    recordVersions(
      arg0: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    setABI(
      node: BytesLike,
      contentType: BigNumberish,
      data: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    supportsInterface(
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}