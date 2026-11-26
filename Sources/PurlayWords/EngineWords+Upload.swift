import Foundation
import PurlayContract
import PurlayKit

extension EngineWords {
    /// What a file's failure says, in words from what the server answered (D-159, D-164).
    public static func upload(_ failure: UploadFailure) -> LocalizedStringResource {
        switch failure {
        case .empty: return LocalizedStringResource("This file is empty.", bundle: .module)
        case .tooLarge:
            let limit = ByteCountFormatter.string(
                fromByteCount: Int64(ContractConstants.attachmentBytesMax), countStyle: .file)
            return LocalizedStringResource("This file is larger than the limit of \(limit).", bundle: .module)
        case .imageTooLarge:
            return LocalizedStringResource("This picture is larger than Purlay can take.", bundle: .module)
        case .imageUnreadable: return LocalizedStringResource("This picture cannot be read.", bundle: .module)
        case .unsupported: return LocalizedStringResource("This kind of file is not accepted.", bundle: .module)
        case .storageFull(let remaining):
            let left = ByteCountFormatter.string(fromByteCount: Int64(remaining), countStyle: .file)
            return LocalizedStringResource("The workspace's storage is full. \(left) left.", bundle: .module)
        case .tooManyWaiting:
            return LocalizedStringResource("Too many files are waiting. Send or remove some first.", bundle: .module)
        case .noConnection: return LocalizedStringResource("No connection.", bundle: .module)
        case .busy: return LocalizedStringResource("The server is busy.", bundle: .module)
        case .storageUnavailable:
            return LocalizedStringResource("File storage is unavailable right now.", bundle: .module)
        case .sessionEnded: return LocalizedStringResource("Your session has ended. Sign in again.", bundle: .module)
        case .noAccess: return LocalizedStringResource("You no longer have access here.", bundle: .module)
        case .unknown: return LocalizedStringResource("The file could not be sent.", bundle: .module)
        }
    }
}
