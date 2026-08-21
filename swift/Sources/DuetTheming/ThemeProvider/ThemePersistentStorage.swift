// Copyright (c) 2026 Modaal.dev
// Licensed under the MIT License. See LICENSE file for details.

#if os(iOS)

import UIKit

public final class ThemePersistentStorage: ThemeProviderPersisting {

  public init() {
  }

  public func get<T>(_ type: T.Type, key: String) -> T? where T : Decodable, T : Encodable {
    guard
      let data = UserDefaults.standard.data(forKey: key),
      let value = try? JSONDecoder().decode(T.self, from: data)
    else {
      return nil
    }

    return value
  }

  public func set<T>(_ value: T, key: String) where T : Decodable, T : Encodable {
    do {
      let data = try JSONEncoder().encode(value)
      UserDefaults.standard.set(data, forKey: key)
      UserDefaults.standard.synchronize()
    } catch {
#if DEBUG
      debugPrint(error.localizedDescription)
#endif
    }
  }
}

#endif
