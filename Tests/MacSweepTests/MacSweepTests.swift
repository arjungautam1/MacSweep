import Testing
import Foundation
@testable import MacSweep

@Suite("MacSweep Comprehensive Test Suite")
struct MacSweepTests {

    @Test("PathSafetyValidator prevents deletion of root, system, and critical user files")
    func testPathSafetyValidation() throws {
        let root = URL(fileURLWithPath: "/")
        let systemDir = URL(fileURLWithPath: "/System/Library")
        let binDir = URL(fileURLWithPath: "/bin/zsh")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sshDir = home.appendingPathComponent(".ssh")
        let zshrc = home.appendingPathComponent(".zshrc")

        #expect(PathSafetyValidator.isProtectedUserPath(root) == true)
        #expect(PathSafetyValidator.isProtectedUserPath(systemDir) == true)
        #expect(PathSafetyValidator.isProtectedUserPath(binDir) == true)
        #expect(PathSafetyValidator.isProtectedUserPath(home) == true)
        #expect(PathSafetyValidator.isProtectedUserPath(sshDir) == true)
        #expect(PathSafetyValidator.isProtectedUserPath(zshrc) == true)

        // Safe disposable cache path should NOT be protected
        let safeCache = home.appendingPathComponent("Library/Caches/com.example.testapp")
        #expect(PathSafetyValidator.isProtectedUserPath(safeCache) == false)
    }

    @Test("Nested path deduplication removes subpaths when parent directory is targeted")
    func testNestedPathDeduplication() throws {
        let parent = URL(fileURLWithPath: "/tmp/projectA")
        let child1 = URL(fileURLWithPath: "/tmp/projectA/node_modules")
        let child2 = URL(fileURLWithPath: "/tmp/projectA/node_modules/lodash")
        let sibling = URL(fileURLWithPath: "/tmp/projectB")

        let input = [parent, child1, child2, sibling]
        let deduplicated = PathSafetyValidator.deduplicateNestedPaths(input)

        #expect(deduplicated.count == 2)
        let paths = Set(deduplicated.map { $0.path })
        #expect(paths.contains("/tmp/projectA"))
        #expect(paths.contains("/tmp/projectB"))
        #expect(!paths.contains("/tmp/projectA/node_modules"))
    }

    @Test("Dry run simulation preserves files on disk")
    func testDryRunSimulationMode() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testFile = tempDir.appendingPathComponent("sample_cache.tmp")
        try "test cache content".write(to: testFile, atomically: true, encoding: .utf8)

        let candidate = CleanupCandidate(
            name: "Sample Cache",
            path: testFile,
            size: 100,
            category: .cachesAndTemp,
            whatItContains: "Temporary test cache",
            whyItExists: "Created by unit test",
            removalConsequence: "Safe",
            isRebuildable: true,
            confidence: .verified,
            isSafeByDefault: true,
            isSelected: true
        )

        let plan = CleanupExecutorService.shared.prepareCleanupPlan(
            from: [candidate],
            useTrash: true,
            isDryRun: true
        )

        let report = await CleanupExecutorService.shared.executeCleanup(plan: plan)

        #expect(report.isDryRun == true)
        #expect(report.items.first?.status == .simulated)
        // File must still exist on disk after dry run!
        #expect(FileManager.default.fileExists(atPath: testFile.path) == true)
    }

    @Test("Recoverable cleanup moves test fixture to Trash")
    func testRecoverableCleanupToTrash() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let testFile = tempDir.appendingPathComponent("disposable_file.log")
        try "log file entry".write(to: testFile, atomically: true, encoding: .utf8)

        let candidate = CleanupCandidate(
            name: "Disposable File",
            path: testFile,
            size: 50,
            category: .installersAndLogs,
            whatItContains: "Log file",
            whyItExists: "Test fixture",
            removalConsequence: "Will be moved to Trash",
            isRebuildable: true,
            confidence: .verified,
            isSafeByDefault: true,
            isSelected: true
        )

        let plan = CleanupExecutorService.shared.prepareCleanupPlan(
            from: [candidate],
            useTrash: true,
            isDryRun: false
        )

        let report = await CleanupExecutorService.shared.executeCleanup(plan: plan)

        #expect(report.isDryRun == false)
        #expect(report.items.first?.status == .movedToTrash)
        #expect(report.items.first?.trashURL != nil)
        #expect(FileManager.default.fileExists(atPath: testFile.path) == false)

        // Clean up Trash item if created
        if let trashURL = report.items.first?.trashURL {
            try? FileManager.default.removeItem(at: trashURL)
        }
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Duplicate file detection identifies identical contents using SHA-256")
    func testDuplicateFileDetection() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("copy1.dat")
        let file2 = tempDir.appendingPathComponent("copy2.dat")
        let file3 = tempDir.appendingPathComponent("unique.dat")

        let identicalData = Data(repeating: 0x42, count: 1024)
        let uniqueData = Data(repeating: 0x99, count: 1024)

        try identicalData.write(to: file1)
        try identicalData.write(to: file2)
        try uniqueData.write(to: file3)

        let items = [
            LargeFileItem(name: "copy1.dat", path: file1, size: 1024, kind: .generic),
            LargeFileItem(name: "copy2.dat", path: file2, size: 1024, kind: .generic),
            LargeFileItem(name: "unique.dat", path: file3, size: 1024, kind: .generic)
        ]

        let evaluated = LargeFileAnalyzerService.shared.identifyDuplicates(in: items)

        let dupes = evaluated.filter { $0.isDuplicate }
        #expect(dupes.count == 2)
        let nonDupes = evaluated.filter { !$0.isDuplicate }
        #expect(nonDupes.count == 1)
        #expect(nonDupes.first?.name == "unique.dat")
    }

    @Test("StorageNode generates properly escaped terminal commands")
    func testStorageNodeCommands() throws {
        let folderWithSpaces = URL(fileURLWithPath: "/Users/test/My Documents/Project Alpha")
        let node = StorageNode(url: folderWithSpaces, name: "Project Alpha", isDirectory: true, size: 1024)

        #expect(node.cdCommand == "cd /Users/test/My\\ Documents/Project\\ Alpha")
        #expect(node.duCommand == "du -sh /Users/test/My\\ Documents/Project\\ Alpha")
        #expect(node.openCommand == "open /Users/test/My\\ Documents/Project\\ Alpha")
    }

    @Test("DiskPermissionService safely evaluates disk access")
    @MainActor
    func testDiskPermissionService() throws {
        let service = DiskPermissionService.shared
        let access = service.checkAccess()
        // Must match published property state
        #expect(service.hasFullDiskAccess == access)
    }

    @Test("Targeted CleanupPlan preparation excludes unselected or non-targeted candidates")
    func testTargetedCleanupPlan() throws {
        var dummy1 = CleanupCandidate(
            name: "Candidate 1",
            path: URL(fileURLWithPath: "/tmp/cand1"),
            size: 500,
            category: .cachesAndTemp,
            whatItContains: "Cache 1",
            whyItExists: "Test",
            removalConsequence: "Safe",
            isRebuildable: true
        )
        dummy1.isSelected = false

        var dummy2 = CleanupCandidate(
            name: "Candidate 2",
            path: URL(fileURLWithPath: "/tmp/cand2"),
            size: 1500,
            category: .cachesAndTemp,
            whatItContains: "Cache 2",
            whyItExists: "Test",
            removalConsequence: "Safe",
            isRebuildable: true
        )
        dummy2.isSelected = true

        // Mixed candidate pool: only dummy2 has isSelected = true
        let plan = CleanupExecutorService.shared.prepareCleanupPlan(
            from: [dummy1, dummy2],
            useTrash: true,
            isDryRun: true
        )

        #expect(plan.candidates.count == 1)
        #expect(plan.candidates.first?.id == dummy2.id)
        #expect(plan.totalEstimatedReclaimableBytes == 1500)
    }
}

