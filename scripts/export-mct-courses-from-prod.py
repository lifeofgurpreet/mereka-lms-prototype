#!/usr/bin/env python3
"""
Export MCT courses from production MongoDB to JSON files
"""
import os

import pymongo
from bson import json_util


def main():
    # Connect to MongoDB
    mongo_host = os.environ.get('MONGODB_HOST', 'mongodb')
    mongo_port = int(os.environ.get('MONGODB_PORT', 27017))

    print(f"Connecting to MongoDB at {mongo_host}:{mongo_port}")
    client = pymongo.MongoClient(mongo_host, mongo_port)
    db = client.openedx

    # Find MCT courses
    print("Finding MCT courses...")
    courses = list(db.modulestore.active_versions.find({'course': {'$regex': 'MCTCAT'}}))
    print(f"Found {len(courses)} MCT courses:")
    for c in courses:
        print(f"  - {c['org']}+{c['course']}+{c['run']}")

    export_data = {
        'active_versions': [],
        'structures': [],
        'definitions': []
    }

    # Export active_versions
    print("\nExporting active_versions...")
    for course in courses:
        export_data['active_versions'].append(course)

    # Export structures
    print("Exporting structures...")
    structure_ids = set()
    for course in courses:
        versions = course.get('versions', {})
        for _branch, struct_id in versions.items():
            if struct_id and struct_id not in structure_ids:
                structure_ids.add(struct_id)
                struct = db.modulestore.structures.find_one({'_id': struct_id})
                if struct:
                    export_data['structures'].append(struct)
                    print(f"  - Structure {struct_id} ({len(json_util.dumps(struct))} bytes)")

    # Export definitions
    print("Exporting definitions...")
    definition_ids = set()
    for struct in export_data['structures']:
        blocks = struct.get('blocks', {})
        for _block_id, block_data in blocks.items():
            def_id = block_data.get('definition')
            if def_id and def_id not in definition_ids:
                definition_ids.add(def_id)
                definition = db.modulestore.definitions.find_one({'_id': def_id})
                if definition:
                    export_data['definitions'].append(definition)

    print("\nExport summary:")
    print(f"  Active versions: {len(export_data['active_versions'])}")
    print(f"  Structures: {len(export_data['structures'])}")
    print(f"  Definitions: {len(export_data['definitions'])}")

    # Write to stdout as JSON
    print("\n=== JSON START ===")
    print(json_util.dumps(export_data, indent=2))
    print("=== JSON END ===")

if __name__ == '__main__':
    main()
