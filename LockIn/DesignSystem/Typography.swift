import SwiftUI

struct Typography {
  // Font families - Montserrat preferred, SF Pro fallback
  static let primaryFont = "Montserrat"
  static let fallbackFont = "SF Pro"

  // Font weights
  static let regular = Font.Weight.regular
  static let semibold = Font.Weight.semibold
  static let bold = Font.Weight.bold

  // Text styles
  static let largeTitle = Font.custom(primaryFont, size: 34, relativeTo: .largeTitle)
    .weight(bold)

  static let title = Font.custom(primaryFont, size: 28, relativeTo: .title)
    .weight(semibold)

  static let title2 = Font.custom(primaryFont, size: 22, relativeTo: .title2)
    .weight(semibold)

  static let title3 = Font.custom(primaryFont, size: 20, relativeTo: .title3)
    .weight(semibold)

  static let headline = Font.custom(primaryFont, size: 17, relativeTo: .headline)
    .weight(semibold)

  static let body = Font.custom(primaryFont, size: 17, relativeTo: .body)
    .weight(regular)

  static let callout = Font.custom(primaryFont, size: 16, relativeTo: .callout)
    .weight(regular)

  static let subheadline = Font.custom(primaryFont, size: 15, relativeTo: .subheadline)
    .weight(regular)

  static let footnote = Font.custom(primaryFont, size: 13, relativeTo: .footnote)
    .weight(regular)

  static let caption = Font.custom(primaryFont, size: 12, relativeTo: .caption)
    .weight(regular)

  static let caption2 = Font.custom(primaryFont, size: 11, relativeTo: .caption2)
    .weight(regular)
}

// Convenience extensions for common text styles
extension Text {
  func largeTitleStyle() -> some View {
    self.font(Typography.largeTitle)
  }

  func titleStyle() -> some View {
    self.font(Typography.title)
  }

  func title2Style() -> some View {
    self.font(Typography.title2)
  }

  func title3Style() -> some View {
    self.font(Typography.title3)
  }

  func headlineStyle() -> some View {
    self.font(Typography.headline)
  }

  func bodyStyle() -> some View {
    self.font(Typography.body)
  }

  func calloutStyle() -> some View {
    self.font(Typography.callout)
  }

  func subheadlineStyle() -> some View {
    self.font(Typography.subheadline)
  }

  func footnoteStyle() -> some View {
    self.font(Typography.footnote)
  }

  func captionStyle() -> some View {
    self.font(Typography.caption)
  }

  func caption2Style() -> some View {
    self.font(Typography.caption2)
  }
}
