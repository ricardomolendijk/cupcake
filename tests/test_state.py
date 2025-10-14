"""
Unit tests for operator state module
"""
import unittest
from unittest.mock import Mock, patch, MagicMock
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'operator'))

from lib import state


class TestState(unittest.TestCase):
    
    def test_deep_merge_basic(self):
        """Test basic dictionary merging"""
        base = {'a': 1, 'b': 2}
        updates = {'b': 3, 'c': 4}
        
        result = state.deep_merge(base, updates)
        
        self.assertEqual(result['a'], 1)
        self.assertEqual(result['b'], 3)
        self.assertEqual(result['c'], 4)
    
    def test_deep_merge_nested(self):
        """Test nested dictionary merging"""
        base = {
            'nodes': {
                'node-1': {'phase': 'Pending', 'message': 'old'},
                'node-2': {'phase': 'Pending'}
            }
        }
        updates = {
            'nodes': {
                'node-1': {'phase': 'Upgrading'},
                'node-3': {'phase': 'Pending'}
            }
        }
        
        result = state.deep_merge(base, updates)
        
        # node-1 should be updated but keep message
        self.assertEqual(result['nodes']['node-1']['phase'], 'Upgrading')
        self.assertEqual(result['nodes']['node-1']['message'], 'old')
        
        # node-2 should remain
        self.assertEqual(result['nodes']['node-2']['phase'], 'Pending')
        
        # node-3 should be added
        self.assertEqual(result['nodes']['node-3']['phase'], 'Pending')
    
    def test_compute_summary(self):
        """Test summary computation from node statuses"""
        nodes_status = {
            'node-1': {'phase': 'Completed'},
            'node-2': {'phase': 'Upgrading'},
            'node-3': {'phase': 'Pending'},
            'node-4': {'phase': 'Failed'},
            'node-5': {'phase': 'Draining'}
        }
        
        summary = state.compute_summary(nodes_status)
        
        self.assertEqual(summary['total'], 5)
        self.assertEqual(summary['completed'], 1)
        self.assertEqual(summary['upgrading'], 2)  # Upgrading + Draining
        self.assertEqual(summary['pending'], 1)
        self.assertEqual(summary['failed'], 1)
    
    def test_compute_summary_empty(self):
        """Test summary with no nodes"""
        summary = state.compute_summary({})
        
        self.assertEqual(summary['total'], 0)
        self.assertEqual(summary['completed'], 0)
        self.assertEqual(summary['upgrading'], 0)
        self.assertEqual(summary['pending'], 0)
        self.assertEqual(summary['failed'], 0)


if __name__ == '__main__':
    unittest.main()
