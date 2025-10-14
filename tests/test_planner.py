"""
Unit tests for operator planner module
"""
import unittest
from unittest.mock import Mock, patch, MagicMock
from kubernetes import client

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'operator'))

from lib import planner


class TestPlanner(unittest.TestCase):
    
    @patch('lib.planner.client.CoreV1Api')
    def test_make_plan_basic(self, mock_v1_api):
        """Test basic plan creation"""
        # Mock nodes
        mock_node1 = Mock()
        mock_node1.metadata.name = 'master-1'
        mock_node1.metadata.labels = {
            'node-role.kubernetes.io/control-plane': ''
        }
        
        mock_node2 = Mock()
        mock_node2.metadata.name = 'worker-1'
        mock_node2.metadata.labels = {}
        
        mock_node3 = Mock()
        mock_node3.metadata.name = 'worker-2'
        mock_node3.metadata.labels = {}
        
        mock_list = Mock()
        mock_list.items = [mock_node1, mock_node2, mock_node3]
        
        mock_api_instance = Mock()
        mock_api_instance.list_node.return_value = mock_list
        mock_v1_api.return_value = mock_api_instance
        
        # Test
        spec = {'targetVersion': '1.27.4'}
        plan = planner.make_plan(spec)
        
        # Assertions
        self.assertEqual(len(plan['control_plane_nodes']), 1)
        self.assertEqual(len(plan['worker_nodes']), 2)
        self.assertEqual(plan['total'], 3)
        self.assertIn('master-1', plan['control_plane_nodes'])
        self.assertIn('worker-1', plan['worker_nodes'])
        self.assertIn('worker-2', plan['worker_nodes'])
    
    @patch('lib.planner.client.CoreV1Api')
    def test_make_plan_with_node_selector(self, mock_v1_api):
        """Test plan creation with node selector"""
        # Mock nodes
        mock_node1 = Mock()
        mock_node1.metadata.name = 'worker-1'
        mock_node1.metadata.labels = {'env': 'prod'}
        
        mock_node2 = Mock()
        mock_node2.metadata.name = 'worker-2'
        mock_node2.metadata.labels = {'env': 'dev'}
        
        mock_list = Mock()
        mock_list.items = [mock_node1, mock_node2]
        
        mock_api_instance = Mock()
        mock_api_instance.list_node.return_value = mock_list
        mock_v1_api.return_value = mock_api_instance
        
        # Test with node selector
        spec = {
            'targetVersion': '1.27.4',
            'nodeSelector': {'env': 'prod'}
        }
        plan = planner.make_plan(spec)
        
        # Should only include worker-1
        self.assertEqual(plan['total'], 1)
        self.assertIn('worker-1', plan['worker_nodes'])
        self.assertNotIn('worker-2', plan['worker_nodes'])
    
    @patch('lib.planner.client.CoreV1Api')
    def test_make_plan_with_canary(self, mock_v1_api):
        """Test plan creation with canary nodes"""
        # Mock nodes
        workers = []
        for i in range(1, 6):
            node = Mock()
            node.metadata.name = f'worker-{i}'
            node.metadata.labels = {}
            workers.append(node)
        
        mock_list = Mock()
        mock_list.items = workers
        
        mock_api_instance = Mock()
        mock_api_instance.list_node.return_value = mock_list
        mock_v1_api.return_value = mock_api_instance
        
        # Test with canary
        spec = {
            'targetVersion': '1.27.4',
            'canary': {
                'enabled': True,
                'nodes': ['worker-3', 'worker-5']
            }
        }
        plan = planner.make_plan(spec)
        
        # Canary nodes should be first
        self.assertEqual(plan['worker_nodes'][0], 'worker-3')
        self.assertEqual(plan['worker_nodes'][1], 'worker-5')
        self.assertEqual(len(plan['worker_nodes']), 5)


if __name__ == '__main__':
    unittest.main()
