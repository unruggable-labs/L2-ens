/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  BaseContract,
  BigNumber,
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

export interface NameResolverInterface extends utils.Interface {
  functions: {
    "clearRecords(bytes32)": FunctionFragment;
    "name(bytes32)": FunctionFragment;
    "recordVersions(bytes32)": FunctionFragment;
    "setName(bytes32,string)": FunctionFragment;
    "supportsInterface(bytes4)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "clearRecords",
    values: [BytesLike]
  ): string;
  encodeFunctionData(functionFragment: "name", values: [BytesLike]): string;
  encodeFunctionData(
    functionFragment: "recordVersions",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "setName",
    values: [BytesLike, string]
  ): string;
  encodeFunctionData(
    functionFragment: "supportsInterface",
    values: [BytesLike]
  ): string;

  decodeFunctionResult(
    functionFragment: "clearRecords",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "name", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "recordVersions",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "setName", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "supportsInterface",
    data: BytesLike
  ): Result;

  events: {
    "NameChanged(bytes32,string)": EventFragment;
    "VersionChanged(bytes32,uint64)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "NameChanged"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "VersionChanged"): EventFragment;
}

export type NameChangedEvent = TypedEvent<
  [string, string],
  { node: string; name: string }
>;

export type NameChangedEventFilter = TypedEventFilter<NameChangedEvent>;

export type VersionChangedEvent = TypedEvent<
  [string, BigNumber],
  { node: string; newVersion: BigNumber }
>;

export type VersionChangedEventFilter = TypedEventFilter<VersionChangedEvent>;

export interface NameResolver extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: NameResolverInterface;

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
    clearRecords(
      node: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    name(node: BytesLike, overrides?: CallOverrides): Promise<[string]>;

    recordVersions(
      arg0: BytesLike,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    setName(
      node: BytesLike,
      newName: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<ContractTransaction>;

    supportsInterface(
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<[boolean]>;
  };

  clearRecords(
    node: BytesLike,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  name(node: BytesLike, overrides?: CallOverrides): Promise<string>;

  recordVersions(
    arg0: BytesLike,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  setName(
    node: BytesLike,
    newName: string,
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<ContractTransaction>;

  supportsInterface(
    interfaceID: BytesLike,
    overrides?: CallOverrides
  ): Promise<boolean>;

  callStatic: {
    clearRecords(node: BytesLike, overrides?: CallOverrides): Promise<void>;

    name(node: BytesLike, overrides?: CallOverrides): Promise<string>;

    recordVersions(
      arg0: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    setName(
      node: BytesLike,
      newName: string,
      overrides?: CallOverrides
    ): Promise<void>;

    supportsInterface(
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<boolean>;
  };

  filters: {
    "NameChanged(bytes32,string)"(
      node?: BytesLike | null,
      name?: null
    ): NameChangedEventFilter;
    NameChanged(node?: BytesLike | null, name?: null): NameChangedEventFilter;

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
    clearRecords(
      node: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    name(node: BytesLike, overrides?: CallOverrides): Promise<BigNumber>;

    recordVersions(
      arg0: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    setName(
      node: BytesLike,
      newName: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<BigNumber>;

    supportsInterface(
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    clearRecords(
      node: BytesLike,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    name(
      node: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    recordVersions(
      arg0: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    setName(
      node: BytesLike,
      newName: string,
      overrides?: Overrides & { from?: string | Promise<string> }
    ): Promise<PopulatedTransaction>;

    supportsInterface(
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}