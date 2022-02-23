extends "res://addons/gut/test.gd"

const ObsWebsocket := preload("res://addons/obs-websocket-gd/obs_websocket.gd")

# Base message type
const ObsMessage := ObsWebsocket.ObsMessage

#region Abstract message types

const ClientObsMessage := ObsWebsocket.ClientObsMessage
const ServerObsMessage := ObsWebsocket.ServerObsMessage

#endregion

#region OpCode messages

const Hello := ObsWebsocket.Hello
const Authentication := ObsWebsocket.Authentication
const Identify := ObsWebsocket.Identify
const Identified := ObsWebsocket.Identified
const Reidentify := ObsWebsocket.Reidentify
const Event := ObsWebsocket.Event
const Request := ObsWebsocket.Request
const RequestResponse := ObsWebsocket.RequestResponse
const RequestStatus := ObsWebsocket.RequestStatus
const RequestBatch := ObsWebsocket.RequestBatch
const RequestBatchResponse := ObsWebsocket.RequestBatchResponse

#endregion

const Error := ObsWebsocket.Error
const OpCodeEnums := ObsWebsocket.OpCodeEnums
