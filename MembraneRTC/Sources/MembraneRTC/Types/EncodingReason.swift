/**
 * Type describing possible reasons of currently selected encoding.
 * - other - the exact reason couldn't be determined
 * - encodingInactive - previously selected encoding became inactive
 * - lowBandwidth - there is no longer enough bandwidth to maintain previously selected encoding
 */
public enum EncodingReason: String {
    case other
    case encodingInactive
    case lowBandwidth
}
