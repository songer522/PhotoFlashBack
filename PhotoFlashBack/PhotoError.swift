//
//  PhotoError.swift
//  PhotoFlashBack
//
//  Created for improved error handling
//

import Foundation

enum PhotoError: LocalizedError {
    case noPhotosFound
    case authorizationDenied
    case networkError(Error)
    case invalidAsset
    case invalidDate
    case arrayIndexOutOfBounds
    case invalidMonth(Int)
    case creationDateMissing
    case geocodingError(Error?)
    case imageProcessingFailed
    case unknown(Error?)
    
    var errorDescription: String? {
        switch self {
        case .noPhotosFound:
            return "未找到照片"
        case .authorizationDenied:
            return "需要照片库访问权限"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidAsset:
            return "无效的照片资源"
        case .invalidDate:
            return "无效的日期"
        case .arrayIndexOutOfBounds:
            return "数组索引越界"
        case .invalidMonth(let month):
            return "无效的月份: \(month)"
        case .creationDateMissing:
            return "照片缺少创建日期"
        case .geocodingError(let error):
            return "地理位置解析失败: \(error?.localizedDescription ?? "未知错误")"
        case .imageProcessingFailed:
            return "图片处理失败"
        case .unknown(let error):
            return "未知错误: \(error?.localizedDescription ?? "未知")"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noPhotosFound:
            return "请尝试选择其他日期"
        case .authorizationDenied:
            return "请在设置中授予照片库访问权限"
        case .networkError:
            return "请检查网络连接后重试"
        case .invalidAsset, .invalidDate, .arrayIndexOutOfBounds, .invalidMonth:
            return "请刷新页面重试"
        case .creationDateMissing, .imageProcessingFailed:
            return "该照片可能已损坏，请跳过"
        case .geocodingError:
            return "位置信息可能不可用"
        case .unknown:
            return "请稍后重试"
        }
    }
}

// 安全的数组访问扩展
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// 安全的字典访问扩展
extension Dictionary {
    func safeValue(forKey key: Key) -> Value? {
        return self[key]
    }
}

