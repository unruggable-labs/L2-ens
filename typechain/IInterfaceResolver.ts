/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  BaseContract,
  BigNumber,
  BytesLike,
  CallOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import { FunctionFragment, Result, EventFragment } from "@ethersproject/abi";
import { Listener, Provider } from "@ethersproject/providers";
import { TypedEventFilter, TypedEvent, TypedListener, OnEvent } from "./common";

export interface IInterfaceResolverInterface extends utils.Interface {
  functions: {
    "interfaceImplementer(bytes32,bytes4)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "interfaceImplementer",
    values: [BytesLike, BytesLike]
  ): string;

  decodeFunctionResult(
    functionFragment: "interfaceImplementer",
    data: BytesLike
  ): Result;

  events: {
    "InterfaceChanged(bytes32,bytes4,address)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "InterfaceChanged"): EventFragment;
}

export type InterfaceChangedEvent = TypedEvent<
  [string, string, string],
  { node: string; interfaceID: string; implementer: string }
>;

export type InterfaceChangedEventFilter =
  TypedEventFilter<InterfaceChangedEvent>;

export interface IInterfaceResolver extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IInterfaceResolverInterface;

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
    interfaceImplementer(
      node: BytesLike,
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<[string]>;
  };

  interfaceImplementer(
    node: BytesLike,
    interfaceID: BytesLike,
    overrides?: CallOverrides
  ): Promise<string>;

  callStatic: {
    interfaceImplementer(
      node: BytesLike,
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<string>;
  };

  filters: {
    "InterfaceChanged(bytes32,bytes4,address)"(
      node?: BytesLike | null,
      interfaceID?: BytesLike | null,
      implementer?: null
    ): InterfaceChangedEventFilter;
    InterfaceChanged(
      node?: BytesLike | null,
      interfaceID?: BytesLike | null,
      implementer?: null
    ): InterfaceChangedEventFilter;
  };

  estimateGas: {
    interfaceImplementer(
      node: BytesLike,
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    interfaceImplementer(
      node: BytesLike,
      interfaceID: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}