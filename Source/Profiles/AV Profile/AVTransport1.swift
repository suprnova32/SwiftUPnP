import Foundation
import Combine
import XMLCoder
import os.log

public class AVTransport1: UPnPService {
	struct Envelope<T: Codable>: Codable {
		enum CodingKeys: String, CodingKey {
			case body = "s:Body"
		}

		var body: T
	}

	public enum TransportStateEnum: String, Codable {
		case stopped = "STOPPED"
		case playing = "PLAYING"
		case pausedPlayback = "PAUSED_PLAYBACK"
		case transitioning = "TRANSITIONING"
	}

	public enum PlaybackStorageMediumEnum: String, Codable {
		case none = "NONE"
		case network = "NETWORK"
	}

	public enum RecordStorageMediumEnum: String, Codable {
		case none = "NONE"
	}

	public enum CurrentPlayModeEnum: String, Codable {
		case normal = "NORMAL"
		case repeatAll = "REPEAT_ALL"
		case repeatOne = "REPEAT_ONE"
		case shuffleNorepeat = "SHUFFLE_NOREPEAT"
		case shuffle = "SHUFFLE"
		case shuffleRepeatOne = "SHUFFLE_REPEAT_ONE"
	}

	public enum TransportPlaySpeedEnum: String, Codable {
		case one = "1"
	}

	public enum A_ARG_TYPE_SeekModeEnum: String, Codable {
		case trackNr = "TRACK_NR"
		case relTime = "REL_TIME"
		case timeDelta = "TIME_DELTA"
	}

	public func setAVTransportURI(instanceID: UInt32, currentURI: String, currentURIMetaData: String, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case currentURI = "CurrentURI"
				case currentURIMetaData = "CurrentURIMetaData"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var currentURI: String
			public var currentURIMetaData: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:SetAVTransportURI"
			}

			var action: SoapAction
		}
		try await post(action: "SetAVTransportURI", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, currentURI: currentURI, currentURIMetaData: currentURIMetaData))), log: log)
	}

	public func setNextAVTransportURI(instanceID: UInt32, nextURI: String, nextURIMetaData: String, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case nextURI = "NextURI"
				case nextURIMetaData = "NextURIMetaData"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var nextURI: String
			public var nextURIMetaData: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:SetNextAVTransportURI"
			}

			var action: SoapAction
		}
		try await post(action: "SetNextAVTransportURI", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, nextURI: nextURI, nextURIMetaData: nextURIMetaData))), log: log)
	}

	public struct AddURIToQueueResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case firstTrackNumberEnqueued = "FirstTrackNumberEnqueued"
			case numTracksAdded = "NumTracksAdded"
			case newQueueLength = "NewQueueLength"
		}

		public var firstTrackNumberEnqueued: UInt32
		public var numTracksAdded: UInt32
		public var newQueueLength: UInt32

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))AddURIToQueueResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))firstTrackNumberEnqueued: \(firstTrackNumberEnqueued)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))numTracksAdded: \(numTracksAdded)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newQueueLength: \(newQueueLength)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func addURIToQueue(instanceID: UInt32, enqueuedURI: String, enqueuedURIMetaData: String, desiredFirstTrackNumberEnqueued: UInt32, enqueueAsNext: Bool, log: UPnPService.MessageLog = .none) async throws -> AddURIToQueueResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case enqueuedURI = "EnqueuedURI"
				case enqueuedURIMetaData = "EnqueuedURIMetaData"
				case desiredFirstTrackNumberEnqueued = "DesiredFirstTrackNumberEnqueued"
				case enqueueAsNext = "EnqueueAsNext"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var enqueuedURI: String
			public var enqueuedURIMetaData: String
			public var desiredFirstTrackNumberEnqueued: UInt32
			public var enqueueAsNext: Bool
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:AddURIToQueue"
				case response = "u:AddURIToQueueResponse"
			}

			var action: SoapAction?
			var response: AddURIToQueueResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "AddURIToQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, enqueuedURI: enqueuedURI, enqueuedURIMetaData: enqueuedURIMetaData, desiredFirstTrackNumberEnqueued: desiredFirstTrackNumberEnqueued, enqueueAsNext: enqueueAsNext))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct AddMultipleURIsToQueueResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case firstTrackNumberEnqueued = "FirstTrackNumberEnqueued"
			case numTracksAdded = "NumTracksAdded"
			case newQueueLength = "NewQueueLength"
			case newUpdateID = "NewUpdateID"
		}

		public var firstTrackNumberEnqueued: UInt32
		public var numTracksAdded: UInt32
		public var newQueueLength: UInt32
		public var newUpdateID: UInt32

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))AddMultipleURIsToQueueResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))firstTrackNumberEnqueued: \(firstTrackNumberEnqueued)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))numTracksAdded: \(numTracksAdded)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newQueueLength: \(newQueueLength)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newUpdateID: \(newUpdateID)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func addMultipleURIsToQueue(instanceID: UInt32, updateID: UInt32, numberOfURIs: UInt32, enqueuedURIs: String, enqueuedURIsMetaData: String, containerURI: String, containerMetaData: String, desiredFirstTrackNumberEnqueued: UInt32, enqueueAsNext: Bool, log: UPnPService.MessageLog = .none) async throws -> AddMultipleURIsToQueueResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case updateID = "UpdateID"
				case numberOfURIs = "NumberOfURIs"
				case enqueuedURIs = "EnqueuedURIs"
				case enqueuedURIsMetaData = "EnqueuedURIsMetaData"
				case containerURI = "ContainerURI"
				case containerMetaData = "ContainerMetaData"
				case desiredFirstTrackNumberEnqueued = "DesiredFirstTrackNumberEnqueued"
				case enqueueAsNext = "EnqueueAsNext"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var updateID: UInt32
			public var numberOfURIs: UInt32
			public var enqueuedURIs: String
			public var enqueuedURIsMetaData: String
			public var containerURI: String
			public var containerMetaData: String
			public var desiredFirstTrackNumberEnqueued: UInt32
			public var enqueueAsNext: Bool
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:AddMultipleURIsToQueue"
				case response = "u:AddMultipleURIsToQueueResponse"
			}

			var action: SoapAction?
			var response: AddMultipleURIsToQueueResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "AddMultipleURIsToQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, updateID: updateID, numberOfURIs: numberOfURIs, enqueuedURIs: enqueuedURIs, enqueuedURIsMetaData: enqueuedURIsMetaData, containerURI: containerURI, containerMetaData: containerMetaData, desiredFirstTrackNumberEnqueued: desiredFirstTrackNumberEnqueued, enqueueAsNext: enqueueAsNext))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public func reorderTracksInQueue(instanceID: UInt32, startingIndex: UInt32, numberOfTracks: UInt32, insertBefore: UInt32, updateID: UInt32, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case startingIndex = "StartingIndex"
				case numberOfTracks = "NumberOfTracks"
				case insertBefore = "InsertBefore"
				case updateID = "UpdateID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var startingIndex: UInt32
			public var numberOfTracks: UInt32
			public var insertBefore: UInt32
			public var updateID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:ReorderTracksInQueue"
			}

			var action: SoapAction
		}
		try await post(action: "ReorderTracksInQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, startingIndex: startingIndex, numberOfTracks: numberOfTracks, insertBefore: insertBefore, updateID: updateID))), log: log)
	}

	public func removeTrackFromQueue(instanceID: UInt32, objectID: String, updateID: UInt32, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case objectID = "ObjectID"
				case updateID = "UpdateID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var objectID: String
			public var updateID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:RemoveTrackFromQueue"
			}

			var action: SoapAction
		}
		try await post(action: "RemoveTrackFromQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, objectID: objectID, updateID: updateID))), log: log)
	}

	public struct RemoveTrackRangeFromQueueResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case newUpdateID = "NewUpdateID"
		}

		public var newUpdateID: UInt32

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))RemoveTrackRangeFromQueueResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newUpdateID: \(newUpdateID)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func removeTrackRangeFromQueue(instanceID: UInt32, updateID: UInt32, startingIndex: UInt32, numberOfTracks: UInt32, log: UPnPService.MessageLog = .none) async throws -> RemoveTrackRangeFromQueueResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case updateID = "UpdateID"
				case startingIndex = "StartingIndex"
				case numberOfTracks = "NumberOfTracks"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var updateID: UInt32
			public var startingIndex: UInt32
			public var numberOfTracks: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:RemoveTrackRangeFromQueue"
				case response = "u:RemoveTrackRangeFromQueueResponse"
			}

			var action: SoapAction?
			var response: RemoveTrackRangeFromQueueResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "RemoveTrackRangeFromQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, updateID: updateID, startingIndex: startingIndex, numberOfTracks: numberOfTracks))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public func removeAllTracksFromQueue(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:RemoveAllTracksFromQueue"
			}

			var action: SoapAction
		}
		try await post(action: "RemoveAllTracksFromQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)
	}

	public struct SaveQueueResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case assignedObjectID = "AssignedObjectID"
		}

		public var assignedObjectID: String

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))SaveQueueResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))assignedObjectID: '\(assignedObjectID)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func saveQueue(instanceID: UInt32, title: String, objectID: String, log: UPnPService.MessageLog = .none) async throws -> SaveQueueResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case title = "Title"
				case objectID = "ObjectID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var title: String
			public var objectID: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:SaveQueue"
				case response = "u:SaveQueueResponse"
			}

			var action: SoapAction?
			var response: SaveQueueResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "SaveQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, title: title, objectID: objectID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public func backupQueue(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:BackupQueue"
			}

			var action: SoapAction
		}
		try await post(action: "BackupQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)
	}

	public struct CreateSavedQueueResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case numTracksAdded = "NumTracksAdded"
			case newQueueLength = "NewQueueLength"
			case assignedObjectID = "AssignedObjectID"
			case newUpdateID = "NewUpdateID"
		}

		public var numTracksAdded: UInt32
		public var newQueueLength: UInt32
		public var assignedObjectID: String
		public var newUpdateID: UInt32

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))CreateSavedQueueResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))numTracksAdded: \(numTracksAdded)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newQueueLength: \(newQueueLength)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))assignedObjectID: '\(assignedObjectID)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newUpdateID: \(newUpdateID)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func createSavedQueue(instanceID: UInt32, title: String, enqueuedURI: String, enqueuedURIMetaData: String, log: UPnPService.MessageLog = .none) async throws -> CreateSavedQueueResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case title = "Title"
				case enqueuedURI = "EnqueuedURI"
				case enqueuedURIMetaData = "EnqueuedURIMetaData"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var title: String
			public var enqueuedURI: String
			public var enqueuedURIMetaData: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:CreateSavedQueue"
				case response = "u:CreateSavedQueueResponse"
			}

			var action: SoapAction?
			var response: CreateSavedQueueResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "CreateSavedQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, title: title, enqueuedURI: enqueuedURI, enqueuedURIMetaData: enqueuedURIMetaData))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct AddURIToSavedQueueResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case numTracksAdded = "NumTracksAdded"
			case newQueueLength = "NewQueueLength"
			case newUpdateID = "NewUpdateID"
		}

		public var numTracksAdded: UInt32
		public var newQueueLength: UInt32
		public var newUpdateID: UInt32

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))AddURIToSavedQueueResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))numTracksAdded: \(numTracksAdded)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newQueueLength: \(newQueueLength)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newUpdateID: \(newUpdateID)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func addURIToSavedQueue(instanceID: UInt32, objectID: String, updateID: UInt32, enqueuedURI: String, enqueuedURIMetaData: String, addAtIndex: UInt32, log: UPnPService.MessageLog = .none) async throws -> AddURIToSavedQueueResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case objectID = "ObjectID"
				case updateID = "UpdateID"
				case enqueuedURI = "EnqueuedURI"
				case enqueuedURIMetaData = "EnqueuedURIMetaData"
				case addAtIndex = "AddAtIndex"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var objectID: String
			public var updateID: UInt32
			public var enqueuedURI: String
			public var enqueuedURIMetaData: String
			public var addAtIndex: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:AddURIToSavedQueue"
				case response = "u:AddURIToSavedQueueResponse"
			}

			var action: SoapAction?
			var response: AddURIToSavedQueueResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "AddURIToSavedQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, objectID: objectID, updateID: updateID, enqueuedURI: enqueuedURI, enqueuedURIMetaData: enqueuedURIMetaData, addAtIndex: addAtIndex))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct ReorderTracksInSavedQueueResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case queueLengthChange = "QueueLengthChange"
			case newQueueLength = "NewQueueLength"
			case newUpdateID = "NewUpdateID"
		}

		public var queueLengthChange: Int32
		public var newQueueLength: UInt32
		public var newUpdateID: UInt32

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))ReorderTracksInSavedQueueResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))queueLengthChange: \(queueLengthChange)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newQueueLength: \(newQueueLength)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newUpdateID: \(newUpdateID)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func reorderTracksInSavedQueue(instanceID: UInt32, objectID: String, updateID: UInt32, trackList: String, newPositionList: String, log: UPnPService.MessageLog = .none) async throws -> ReorderTracksInSavedQueueResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case objectID = "ObjectID"
				case updateID = "UpdateID"
				case trackList = "TrackList"
				case newPositionList = "NewPositionList"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var objectID: String
			public var updateID: UInt32
			public var trackList: String
			public var newPositionList: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:ReorderTracksInSavedQueue"
				case response = "u:ReorderTracksInSavedQueueResponse"
			}

			var action: SoapAction?
			var response: ReorderTracksInSavedQueueResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "ReorderTracksInSavedQueue", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, objectID: objectID, updateID: updateID, trackList: trackList, newPositionList: newPositionList))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct GetMediaInfoResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case nrTracks = "NrTracks"
			case mediaDuration = "MediaDuration"
			case currentURI = "CurrentURI"
			case currentURIMetaData = "CurrentURIMetaData"
			case nextURI = "NextURI"
			case nextURIMetaData = "NextURIMetaData"
			case playMedium = "PlayMedium"
			case recordMedium = "RecordMedium"
			case writeStatus = "WriteStatus"
		}

		public var nrTracks: UInt32
		public var mediaDuration: String
		public var currentURI: String
		public var currentURIMetaData: String
		public var nextURI: String
		public var nextURIMetaData: String
		public var playMedium: PlaybackStorageMediumEnum
		public var recordMedium: RecordStorageMediumEnum
		public var writeStatus: String

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))GetMediaInfoResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))nrTracks: \(nrTracks)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))mediaDuration: '\(mediaDuration)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))currentURI: '\(currentURI)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))currentURIMetaData: '\(currentURIMetaData)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))nextURI: '\(nextURI)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))nextURIMetaData: '\(nextURIMetaData)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))playMedium: \(playMedium.rawValue)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))recordMedium: \(recordMedium.rawValue)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))writeStatus: '\(writeStatus)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func getMediaInfo(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> GetMediaInfoResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:GetMediaInfo"
				case response = "u:GetMediaInfoResponse"
			}

			var action: SoapAction?
			var response: GetMediaInfoResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "GetMediaInfo", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct GetTransportInfoResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case currentTransportState = "CurrentTransportState"
			case currentTransportStatus = "CurrentTransportStatus"
			case currentSpeed = "CurrentSpeed"
		}

		public var currentTransportState: TransportStateEnum
		public var currentTransportStatus: String
		public var currentSpeed: TransportPlaySpeedEnum

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))GetTransportInfoResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))currentTransportState: \(currentTransportState.rawValue)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))currentTransportStatus: '\(currentTransportStatus)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))currentSpeed: \(currentSpeed.rawValue)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func getTransportInfo(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> GetTransportInfoResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:GetTransportInfo"
				case response = "u:GetTransportInfoResponse"
			}

			var action: SoapAction?
			var response: GetTransportInfoResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "GetTransportInfo", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct GetPositionInfoResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case track = "Track"
			case trackDuration = "TrackDuration"
			case trackMetaData = "TrackMetaData"
			case trackURI = "TrackURI"
			case relTime = "RelTime"
			case absTime = "AbsTime"
			case relCount = "RelCount"
			case absCount = "AbsCount"
		}

		public var track: UInt32
		public var trackDuration: String
		public var trackMetaData: String
		public var trackURI: String
		public var relTime: String
		public var absTime: String
		public var relCount: Int32
		public var absCount: Int32

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))GetPositionInfoResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))track: \(track)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))trackDuration: '\(trackDuration)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))trackMetaData: '\(trackMetaData)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))trackURI: '\(trackURI)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))relTime: '\(relTime)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))absTime: '\(absTime)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))relCount: \(relCount)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))absCount: \(absCount)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
        
        public func getTrackMetaData() -> DIDLLite? {
            DIDLLite.from(trackMetaData)
        }
	}
	public func getPositionInfo(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> GetPositionInfoResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:GetPositionInfo"
				case response = "u:GetPositionInfoResponse"
			}

			var action: SoapAction?
			var response: GetPositionInfoResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "GetPositionInfo", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct GetDeviceCapabilitiesResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case playMedia = "PlayMedia"
			case recMedia = "RecMedia"
			case recQualityModes = "RecQualityModes"
		}

		public var playMedia: String
		public var recMedia: String
		public var recQualityModes: String

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))GetDeviceCapabilitiesResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))playMedia: '\(playMedia)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))recMedia: '\(recMedia)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))recQualityModes: '\(recQualityModes)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func getDeviceCapabilities(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> GetDeviceCapabilitiesResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:GetDeviceCapabilities"
				case response = "u:GetDeviceCapabilitiesResponse"
			}

			var action: SoapAction?
			var response: GetDeviceCapabilitiesResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "GetDeviceCapabilities", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct GetTransportSettingsResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case playMode = "PlayMode"
			case recQualityMode = "RecQualityMode"
		}

		public var playMode: CurrentPlayModeEnum
		public var recQualityMode: String

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))GetTransportSettingsResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))playMode: \(playMode.rawValue)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))recQualityMode: '\(recQualityMode)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func getTransportSettings(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> GetTransportSettingsResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:GetTransportSettings"
				case response = "u:GetTransportSettingsResponse"
			}

			var action: SoapAction?
			var response: GetTransportSettingsResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "GetTransportSettings", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct GetCrossfadeModeResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case crossfadeMode = "CrossfadeMode"
		}

		public var crossfadeMode: Bool

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))GetCrossfadeModeResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))crossfadeMode: \(crossfadeMode == true ? "true" : "false")")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func getCrossfadeMode(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> GetCrossfadeModeResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:GetCrossfadeMode"
				case response = "u:GetCrossfadeModeResponse"
			}

			var action: SoapAction?
			var response: GetCrossfadeModeResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "GetCrossfadeMode", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public func stop(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:Stop"
			}

			var action: SoapAction
		}
		try await post(action: "Stop", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)
	}

	public func play(instanceID: UInt32, speed: TransportPlaySpeedEnum, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case speed = "Speed"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var speed: TransportPlaySpeedEnum
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:Play"
			}

			var action: SoapAction
		}
		try await post(action: "Play", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, speed: speed))), log: log)
	}

	public func pause(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:Pause"
			}

			var action: SoapAction
		}
		try await post(action: "Pause", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)
	}

	public func seek(instanceID: UInt32, unit: A_ARG_TYPE_SeekModeEnum, target: String, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case unit = "Unit"
				case target = "Target"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var unit: A_ARG_TYPE_SeekModeEnum
			public var target: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:Seek"
			}

			var action: SoapAction
		}
		try await post(action: "Seek", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, unit: unit, target: target))), log: log)
	}

	public func next(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:Next"
			}

			var action: SoapAction
		}
		try await post(action: "Next", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)
	}

	public func previous(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:Previous"
			}

			var action: SoapAction
		}
		try await post(action: "Previous", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)
	}

	public func setPlayMode(instanceID: UInt32, newPlayMode: CurrentPlayModeEnum, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case newPlayMode = "NewPlayMode"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var newPlayMode: CurrentPlayModeEnum
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:SetPlayMode"
			}

			var action: SoapAction
		}
		try await post(action: "SetPlayMode", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, newPlayMode: newPlayMode))), log: log)
	}

	public func setCrossfadeMode(instanceID: UInt32, crossfadeMode: Bool, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case crossfadeMode = "CrossfadeMode"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var crossfadeMode: Bool
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:SetCrossfadeMode"
			}

			var action: SoapAction
		}
		try await post(action: "SetCrossfadeMode", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, crossfadeMode: crossfadeMode))), log: log)
	}

	public func notifyDeletedURI(instanceID: UInt32, deletedURI: String, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case deletedURI = "DeletedURI"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var deletedURI: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:NotifyDeletedURI"
			}

			var action: SoapAction
		}
		try await post(action: "NotifyDeletedURI", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, deletedURI: deletedURI))), log: log)
	}

	public struct GetCurrentTransportActionsResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case actions = "Actions"
		}

		public var actions: String

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))GetCurrentTransportActionsResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))actions: '\(actions)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func getCurrentTransportActions(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> GetCurrentTransportActionsResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:GetCurrentTransportActions"
				case response = "u:GetCurrentTransportActionsResponse"
			}

			var action: SoapAction?
			var response: GetCurrentTransportActionsResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "GetCurrentTransportActions", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public struct BecomeCoordinatorOfStandaloneGroupResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case delegatedGroupCoordinatorID = "DelegatedGroupCoordinatorID"
			case newGroupID = "NewGroupID"
		}

		public var delegatedGroupCoordinatorID: String
		public var newGroupID: String

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))BecomeCoordinatorOfStandaloneGroupResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))delegatedGroupCoordinatorID: '\(delegatedGroupCoordinatorID)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))newGroupID: '\(newGroupID)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func becomeCoordinatorOfStandaloneGroup(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> BecomeCoordinatorOfStandaloneGroupResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:BecomeCoordinatorOfStandaloneGroup"
				case response = "u:BecomeCoordinatorOfStandaloneGroupResponse"
			}

			var action: SoapAction?
			var response: BecomeCoordinatorOfStandaloneGroupResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "BecomeCoordinatorOfStandaloneGroup", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public func delegateGroupCoordinationTo(instanceID: UInt32, newCoordinator: String, rejoinGroup: Bool, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case newCoordinator = "NewCoordinator"
				case rejoinGroup = "RejoinGroup"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var newCoordinator: String
			public var rejoinGroup: Bool
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:DelegateGroupCoordinationTo"
			}

			var action: SoapAction
		}
		try await post(action: "DelegateGroupCoordinationTo", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, newCoordinator: newCoordinator, rejoinGroup: rejoinGroup))), log: log)
	}

	public func becomeGroupCoordinator(instanceID: UInt32, currentCoordinator: String, currentGroupID: String, otherMembers: String, transportSettings: String, currentURI: String, currentURIMetaData: String, sleepTimerState: String, alarmState: String, streamRestartState: String, currentQueueTrackList: String, currentVLIState: String, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case currentCoordinator = "CurrentCoordinator"
				case currentGroupID = "CurrentGroupID"
				case otherMembers = "OtherMembers"
				case transportSettings = "TransportSettings"
				case currentURI = "CurrentURI"
				case currentURIMetaData = "CurrentURIMetaData"
				case sleepTimerState = "SleepTimerState"
				case alarmState = "AlarmState"
				case streamRestartState = "StreamRestartState"
				case currentQueueTrackList = "CurrentQueueTrackList"
				case currentVLIState = "CurrentVLIState"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var currentCoordinator: String
			public var currentGroupID: String
			public var otherMembers: String
			public var transportSettings: String
			public var currentURI: String
			public var currentURIMetaData: String
			public var sleepTimerState: String
			public var alarmState: String
			public var streamRestartState: String
			public var currentQueueTrackList: String
			public var currentVLIState: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:BecomeGroupCoordinator"
			}

			var action: SoapAction
		}
		try await post(action: "BecomeGroupCoordinator", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, currentCoordinator: currentCoordinator, currentGroupID: currentGroupID, otherMembers: otherMembers, transportSettings: transportSettings, currentURI: currentURI, currentURIMetaData: currentURIMetaData, sleepTimerState: sleepTimerState, alarmState: alarmState, streamRestartState: streamRestartState, currentQueueTrackList: currentQueueTrackList, currentVLIState: currentVLIState))), log: log)
	}

	public func becomeGroupCoordinatorAndSource(instanceID: UInt32, currentCoordinator: String, currentGroupID: String, otherMembers: String, currentURI: String, currentURIMetaData: String, sleepTimerState: String, alarmState: String, streamRestartState: String, currentAVTTrackList: String, currentQueueTrackList: String, currentSourceState: String, resumePlayback: Bool, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case currentCoordinator = "CurrentCoordinator"
				case currentGroupID = "CurrentGroupID"
				case otherMembers = "OtherMembers"
				case currentURI = "CurrentURI"
				case currentURIMetaData = "CurrentURIMetaData"
				case sleepTimerState = "SleepTimerState"
				case alarmState = "AlarmState"
				case streamRestartState = "StreamRestartState"
				case currentAVTTrackList = "CurrentAVTTrackList"
				case currentQueueTrackList = "CurrentQueueTrackList"
				case currentSourceState = "CurrentSourceState"
				case resumePlayback = "ResumePlayback"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var currentCoordinator: String
			public var currentGroupID: String
			public var otherMembers: String
			public var currentURI: String
			public var currentURIMetaData: String
			public var sleepTimerState: String
			public var alarmState: String
			public var streamRestartState: String
			public var currentAVTTrackList: String
			public var currentQueueTrackList: String
			public var currentSourceState: String
			public var resumePlayback: Bool
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:BecomeGroupCoordinatorAndSource"
			}

			var action: SoapAction
		}
		try await post(action: "BecomeGroupCoordinatorAndSource", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, currentCoordinator: currentCoordinator, currentGroupID: currentGroupID, otherMembers: otherMembers, currentURI: currentURI, currentURIMetaData: currentURIMetaData, sleepTimerState: sleepTimerState, alarmState: alarmState, streamRestartState: streamRestartState, currentAVTTrackList: currentAVTTrackList, currentQueueTrackList: currentQueueTrackList, currentSourceState: currentSourceState, resumePlayback: resumePlayback))), log: log)
	}

	public func changeCoordinator(instanceID: UInt32, currentCoordinator: String, newCoordinator: String, newTransportSettings: String, currentAVTransportURI: String, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case currentCoordinator = "CurrentCoordinator"
				case newCoordinator = "NewCoordinator"
				case newTransportSettings = "NewTransportSettings"
				case currentAVTransportURI = "CurrentAVTransportURI"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var currentCoordinator: String
			public var newCoordinator: String
			public var newTransportSettings: String
			public var currentAVTransportURI: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:ChangeCoordinator"
			}

			var action: SoapAction
		}
		try await post(action: "ChangeCoordinator", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, currentCoordinator: currentCoordinator, newCoordinator: newCoordinator, newTransportSettings: newTransportSettings, currentAVTransportURI: currentAVTransportURI))), log: log)
	}

	public func changeTransportSettings(instanceID: UInt32, newTransportSettings: String, currentAVTransportURI: String, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case newTransportSettings = "NewTransportSettings"
				case currentAVTransportURI = "CurrentAVTransportURI"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var newTransportSettings: String
			public var currentAVTransportURI: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:ChangeTransportSettings"
			}

			var action: SoapAction
		}
		try await post(action: "ChangeTransportSettings", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, newTransportSettings: newTransportSettings, currentAVTransportURI: currentAVTransportURI))), log: log)
	}

	public func configureSleepTimer(instanceID: UInt32, newSleepTimerDuration: String, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case newSleepTimerDuration = "NewSleepTimerDuration"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var newSleepTimerDuration: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:ConfigureSleepTimer"
			}

			var action: SoapAction
		}
		try await post(action: "ConfigureSleepTimer", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, newSleepTimerDuration: newSleepTimerDuration))), log: log)
	}

	public struct GetRemainingSleepTimerDurationResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case remainingSleepTimerDuration = "RemainingSleepTimerDuration"
			case currentSleepTimerGeneration = "CurrentSleepTimerGeneration"
		}

		public var remainingSleepTimerDuration: String
		public var currentSleepTimerGeneration: UInt32

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))GetRemainingSleepTimerDurationResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))remainingSleepTimerDuration: '\(remainingSleepTimerDuration)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))currentSleepTimerGeneration: \(currentSleepTimerGeneration)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func getRemainingSleepTimerDuration(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> GetRemainingSleepTimerDurationResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:GetRemainingSleepTimerDuration"
				case response = "u:GetRemainingSleepTimerDurationResponse"
			}

			var action: SoapAction?
			var response: GetRemainingSleepTimerDurationResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "GetRemainingSleepTimerDuration", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public func runAlarm(instanceID: UInt32, alarmID: UInt32, loggedStartTime: String, duration: String, programURI: String, programMetaData: String, playMode: CurrentPlayModeEnum, volume: UInt16, includeLinkedZones: Bool, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case alarmID = "AlarmID"
				case loggedStartTime = "LoggedStartTime"
				case duration = "Duration"
				case programURI = "ProgramURI"
				case programMetaData = "ProgramMetaData"
				case playMode = "PlayMode"
				case volume = "Volume"
				case includeLinkedZones = "IncludeLinkedZones"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var alarmID: UInt32
			public var loggedStartTime: String
			public var duration: String
			public var programURI: String
			public var programMetaData: String
			public var playMode: CurrentPlayModeEnum
			public var volume: UInt16
			public var includeLinkedZones: Bool
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:RunAlarm"
			}

			var action: SoapAction
		}
		try await post(action: "RunAlarm", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, alarmID: alarmID, loggedStartTime: loggedStartTime, duration: duration, programURI: programURI, programMetaData: programMetaData, playMode: playMode, volume: volume, includeLinkedZones: includeLinkedZones))), log: log)
	}

	public func startAutoplay(instanceID: UInt32, programURI: String, programMetaData: String, volume: UInt16, includeLinkedZones: Bool, resetVolumeAfter: Bool, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case programURI = "ProgramURI"
				case programMetaData = "ProgramMetaData"
				case volume = "Volume"
				case includeLinkedZones = "IncludeLinkedZones"
				case resetVolumeAfter = "ResetVolumeAfter"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var programURI: String
			public var programMetaData: String
			public var volume: UInt16
			public var includeLinkedZones: Bool
			public var resetVolumeAfter: Bool
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:StartAutoplay"
			}

			var action: SoapAction
		}
		try await post(action: "StartAutoplay", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, programURI: programURI, programMetaData: programMetaData, volume: volume, includeLinkedZones: includeLinkedZones, resetVolumeAfter: resetVolumeAfter))), log: log)
	}

	public struct GetRunningAlarmPropertiesResponse: Codable {
		enum CodingKeys: String, CodingKey {
			case alarmID = "AlarmID"
			case groupID = "GroupID"
			case loggedStartTime = "LoggedStartTime"
		}

		public var alarmID: UInt32
		public var groupID: String
		public var loggedStartTime: String

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))GetRunningAlarmPropertiesResponse {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))alarmID: \(alarmID)")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))groupID: '\(groupID)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))loggedStartTime: '\(loggedStartTime)'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}
	public func getRunningAlarmProperties(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws -> GetRunningAlarmPropertiesResponse {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:GetRunningAlarmProperties"
				case response = "u:GetRunningAlarmPropertiesResponse"
			}

			var action: SoapAction?
			var response: GetRunningAlarmPropertiesResponse?
		}
		let result: Envelope<Body> = try await postWithResult(action: "GetRunningAlarmProperties", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)

		guard let response = result.body.response else { throw ServiceParseError.noValidResponse }
		return response
	}

	public func snoozeAlarm(instanceID: UInt32, duration: String, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
				case duration = "Duration"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
			public var duration: String
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:SnoozeAlarm"
			}

			var action: SoapAction
		}
		try await post(action: "SnoozeAlarm", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID, duration: duration))), log: log)
	}

	public func endDirectControlSession(instanceID: UInt32, log: UPnPService.MessageLog = .none) async throws {
		struct SoapAction: Codable {
			enum CodingKeys: String, CodingKey {
				case urn = "xmlns:u"
				case instanceID = "InstanceID"
			}

			@Attribute var urn: String
			public var instanceID: UInt32
		}
		struct Body: Codable {
			enum CodingKeys: String, CodingKey {
				case action = "u:EndDirectControlSession"
			}

			var action: SoapAction
		}
		try await post(action: "EndDirectControlSession", envelope: Envelope(body: Body(action: SoapAction(urn: Attribute(serviceType), instanceID: instanceID))), log: log)
	}

}

// Event parser
extension AVTransport1 {
	public struct State: Codable {
		enum CodingKeys: String, CodingKey {
			case lastChange = "LastChange"
		}

		public var lastChange: String?

		public func log(deep: Bool = false, indent: Int = 0) {
			Logger.swiftUPnP.debug("\(Logger.indent(indent))AVTransport1State {")
			Logger.swiftUPnP.debug("\(Logger.indent(indent+1))lastChange: '\(lastChange ?? "nil")'")
			Logger.swiftUPnP.debug("\(Logger.indent(indent))}")
		}
	}

	public func state(xml: Data) throws -> State {
		struct PropertySet: Codable {
			var property: [State]
		}

		let decoder = XMLDecoder()
		decoder.shouldProcessNamespaces = true
		let propertySet = try decoder.decode(PropertySet.self, from: xml)

		return propertySet.property.reduce(State()) { partialResult, property in
			var result = partialResult
			if let lastChange = property.lastChange {
				result.lastChange = lastChange
			}
			return result
		}
	}

	public var stateSubject: AnyPublisher<State, Never> {
		subscribedEventPublisher
			.compactMap { [weak self] in
				guard let self else { return nil }

				return try? self.state(xml: $0)
			}
			.eraseToAnyPublisher()
	}
}
