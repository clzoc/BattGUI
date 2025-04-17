# Contribution Guidelines

## Development Setup

### Prerequisites
- Xcode 15+ with command line tools
- Homebrew (for dependency management)
- Swift 5.9+

### Environment Configuration
```bash
# Install build dependencies
brew install swiftlint sourcery

# Clone repository
git clone https://github.com/yourusername/power-suite.git
cd power-suite

# Install pre-commit hooks
swiftlint install-hook
```

## Workflow

1. Create feature branch from `main`
```bash
git checkout -b feat/new-power-metric
```

2. Implement changes following Swift style guide
```bash
swiftlint autocorrect # Before committing
```

3. Update documentation when adding new features

4. Create pull request with:
- Description of changes
- Screenshots for UI changes
- Updated unit tests

## Code Standards

### Swift
- Follow Apple's Swift API Design Guidelines
- Use SwiftLint with included .swiftlint.yml
- Document public APIs using DocC format

### C Code
- Follow Linux kernel coding style for CLI tools
- Include Doxygen comments for complex functions

## Testing Requirements
- 80%+ test coverage for core modules
- Performance tests for battery monitoring
- UI tests for power flow visualization

## Review Process
- All PRs require 2 maintainer approvals
- CI must pass SwiftPM tests and lint checks
- Security-sensitive code requires audit