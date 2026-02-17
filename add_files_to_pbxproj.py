#!/usr/bin/env python3
"""
Script to add 17 new Swift files to the Xcode project.pbxproj file.
"""

import hashlib

PBXPROJ_PATH = "/Users/aranyoray/Documents/komalios/Komalios.xcodeproj/project.pbxproj"

FILES_TO_ADD = [
    # Models
    ("Sources/Komalios/Models/ConversationMemory.swift", "ConversationMemory.swift", "models"),
    ("Sources/Komalios/Models/MoodEntry.swift", "MoodEntry.swift", "models"),
    ("Sources/Komalios/Models/GrowthModels.swift", "GrowthModels.swift", "models"),
    ("Sources/Komalios/Models/RetentionState.swift", "RetentionState.swift", "models"),
    # Services
    ("Sources/Komalios/Services/ConversationMemoryService.swift", "ConversationMemoryService.swift", "services"),
    ("Sources/Komalios/Services/MoodTrackingService.swift", "MoodTrackingService.swift", "services"),
    ("Sources/Komalios/Services/GrowthTrackingService.swift", "GrowthTrackingService.swift", "services"),
    ("Sources/Komalios/Services/ContextualPromptEngine.swift", "ContextualPromptEngine.swift", "services"),
    ("Sources/Komalios/Services/NotificationService.swift", "NotificationService.swift", "services"),
    # Views - Anchors
    ("Sources/Komalios/PostAuth/Views/Anchors/MorningAnchorView.swift", "MorningAnchorView.swift", "views_anchors"),
    ("Sources/Komalios/PostAuth/Views/Anchors/EveningAnchorView.swift", "EveningAnchorView.swift", "views_anchors"),
    # Views - Growth
    ("Sources/Komalios/PostAuth/Views/Growth/GrowthJourneyView.swift", "GrowthJourneyView.swift", "views_growth"),
    ("Sources/Komalios/PostAuth/Views/Growth/WeeklySnapshotView.swift", "WeeklySnapshotView.swift", "views_growth"),
    # Views - Reconnection
    ("Sources/Komalios/PostAuth/Views/Reconnection/ReconnectionView.swift", "ReconnectionView.swift", "views_reconnection"),
    # Views - Insights
    ("Sources/Komalios/PostAuth/Views/Insights/ParentInsightsDashboardView.swift", "ParentInsightsDashboardView.swift", "insights"),
    # Views - Components
    ("Sources/Komalios/PostAuth/Views/Components/ContextualPromptOverlay.swift", "ContextualPromptOverlay.swift", "components"),
    ("Sources/Komalios/PostAuth/Views/Components/MoodHistoryMiniView.swift", "MoodHistoryMiniView.swift", "components"),
]


def generate_id(seed, suffix):
    """Generate a 24-character uppercase hex ID deterministically from a seed."""
    h = hashlib.sha256(f"{seed}_{suffix}".encode()).hexdigest().upper()
    return h[:24]


def add_to_group_children(content, group_id_or_marker, file_ref_id, filename):
    """Add a child reference to a PBXGroup's children array."""
    group_start = content.find(group_id_or_marker)
    if group_start == -1:
        print(f"WARNING: Could not find group marker: {group_id_or_marker}")
        return content

    children_start = content.find("children = (", group_start)
    if children_start == -1:
        print(f"WARNING: Could not find children array for group: {group_id_or_marker}")
        return content

    children_end = content.find("\t\t\t);", children_start)
    if children_end == -1:
        print(f"WARNING: Could not find children closing for group: {group_id_or_marker}")
        return content

    new_child = f'\t\t\t\t{file_ref_id} /* {filename} */,\n'
    content = content[:children_end] + new_child + content[children_end:]
    return content


def main():
    with open(PBXPROJ_PATH, "r") as f:
        content = f.read()

    # Generate IDs for each file
    file_entries = []
    for rel_path, filename, group in FILES_TO_ADD:
        file_ref_id = generate_id(rel_path, "fileref")
        build_file_id = generate_id(rel_path, "buildfile")
        file_entries.append({
            "rel_path": rel_path,
            "filename": filename,
            "group": group,
            "file_ref_id": file_ref_id,
            "build_file_id": build_file_id,
        })

    # Check for ID collisions
    all_ids = set()
    for entry in file_entries:
        for id_val in [entry["file_ref_id"], entry["build_file_id"]]:
            assert id_val not in all_ids, f"ID collision: {id_val}"
            all_ids.add(id_val)
            if id_val in content:
                print(f"WARNING: ID {id_val} already exists in pbxproj!")

    # 1. Add PBXBuildFile entries
    build_file_lines = []
    for entry in file_entries:
        line = f'\t\t{entry["build_file_id"]} /* {entry["filename"]} in Sources */ = {{isa = PBXBuildFile; fileRef = {entry["file_ref_id"]} /* {entry["filename"]} */; }};'
        build_file_lines.append(line)

    build_file_insert = "\n".join(build_file_lines) + "\n"
    content = content.replace(
        "/* End PBXBuildFile section */",
        build_file_insert + "/* End PBXBuildFile section */",
    )

    # 2. Add PBXFileReference entries
    file_ref_lines = []
    for entry in file_entries:
        line = f'\t\t{entry["file_ref_id"]} /* {entry["filename"]} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {entry["filename"]}; sourceTree = "<group>"; }};'
        file_ref_lines.append(line)

    file_ref_insert = "\n".join(file_ref_lines) + "\n"
    content = content.replace(
        "/* End PBXFileReference section */",
        file_ref_insert + "/* End PBXFileReference section */",
    )

    # 3. Create new PBXGroup entries for Anchors, Growth, and Reconnection
    anchors_group_id = generate_id("group_anchors", "group")
    growth_group_id = generate_id("group_growth", "group")
    reconnection_group_id = generate_id("group_reconnection", "group")

    # Anchors group
    anchors_children = []
    for entry in file_entries:
        if entry["group"] == "views_anchors":
            anchors_children.append(f'\t\t\t\t{entry["file_ref_id"]} /* {entry["filename"]} */,')

    anchors_group = (
        f'\t\t{anchors_group_id} /* Anchors */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        + "\n".join(anchors_children) + "\n"
        f'\t\t\t);\n'
        f'\t\t\tpath = Anchors;\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};'
    )

    # Growth group
    growth_children = []
    for entry in file_entries:
        if entry["group"] == "views_growth":
            growth_children.append(f'\t\t\t\t{entry["file_ref_id"]} /* {entry["filename"]} */,')

    growth_group = (
        f'\t\t{growth_group_id} /* Growth */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        + "\n".join(growth_children) + "\n"
        f'\t\t\t);\n'
        f'\t\t\tpath = Growth;\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};'
    )

    # Reconnection group
    reconnection_children = []
    for entry in file_entries:
        if entry["group"] == "views_reconnection":
            reconnection_children.append(f'\t\t\t\t{entry["file_ref_id"]} /* {entry["filename"]} */,')

    reconnection_group = (
        f'\t\t{reconnection_group_id} /* Reconnection */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        + "\n".join(reconnection_children) + "\n"
        f'\t\t\t);\n'
        f'\t\t\tpath = Reconnection;\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};'
    )

    new_groups = anchors_group + "\n" + growth_group + "\n" + reconnection_group + "\n"
    content = content.replace(
        "/* End PBXGroup section */",
        new_groups + "/* End PBXGroup section */",
    )

    # 4. Add files to their respective existing groups

    # Models group: A1000001401D0005 /* Models */
    for entry in file_entries:
        if entry["group"] == "models":
            content = add_to_group_children(
                content, "A1000001401D0005 /* Models */", entry["file_ref_id"], entry["filename"]
            )

    # Services group: A1000001401D0006 /* Services */
    for entry in file_entries:
        if entry["group"] == "services":
            content = add_to_group_children(
                content, "A1000001401D0006 /* Services */", entry["file_ref_id"], entry["filename"]
            )

    # Components group: ECAFED31FAD30DC4853EFDEF /* Components */
    for entry in file_entries:
        if entry["group"] == "components":
            content = add_to_group_children(
                content, "ECAFED31FAD30DC4853EFDEF /* Components */", entry["file_ref_id"], entry["filename"]
            )

    # Insights group: INSIGHTS401D0001 /* Insights */
    for entry in file_entries:
        if entry["group"] == "insights":
            content = add_to_group_children(
                content, "INSIGHTS401D0001 /* Insights */", entry["file_ref_id"], entry["filename"]
            )

    # Add new subgroup references to the Views group (A1000001401D0004 /* Views */)
    content = add_to_group_children(
        content, "A1000001401D0004 /* Views */", anchors_group_id, "Anchors"
    )
    content = add_to_group_children(
        content, "A1000001401D0004 /* Views */", growth_group_id, "Growth"
    )
    content = add_to_group_children(
        content, "A1000001401D0004 /* Views */", reconnection_group_id, "Reconnection"
    )

    # 5. Add build file IDs to PBXSourcesBuildPhase
    sources_phase_marker = "A1000001601D0001 /* Sources */"
    phase_start = content.find(sources_phase_marker)
    if phase_start == -1:
        print("ERROR: Could not find PBXSourcesBuildPhase")
    else:
        files_start = content.find("files = (", phase_start)
        files_end = content.find("\t\t\t);", files_start)

        build_refs = []
        for entry in file_entries:
            build_refs.append(f'\t\t\t\t{entry["build_file_id"]} /* {entry["filename"]} in Sources */,')

        build_refs_insert = "\n".join(build_refs) + "\n"
        content = content[:files_end] + build_refs_insert + content[files_end:]

    # Write back
    with open(PBXPROJ_PATH, "w") as f:
        f.write(content)

    print("Successfully added 17 files to project.pbxproj!")
    print("\nFile entries added:")
    for entry in file_entries:
        print(f"  {entry['filename']}: fileRef={entry['file_ref_id']}, buildFile={entry['build_file_id']}")

    print(f"\nNew groups created:")
    print(f"  Anchors: {anchors_group_id}")
    print(f"  Growth: {growth_group_id}")
    print(f"  Reconnection: {reconnection_group_id}")


if __name__ == "__main__":
    main()
