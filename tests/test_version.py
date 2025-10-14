"""
Unit tests for version management module
"""
import unittest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'operator'))

from lib.version import (
    Version, 
    calculate_upgrade_path, 
    validate_version_string,
    get_upgrade_warnings,
    is_patch_upgrade,
    format_upgrade_path_message
)


class TestVersion(unittest.TestCase):
    
    def test_version_parsing(self):
        """Test version string parsing"""
        v1 = Version("1.27.4")
        self.assertEqual(v1.major, 1)
        self.assertEqual(v1.minor, 27)
        self.assertEqual(v1.patch, 4)
        
        v2 = Version("v1.28.0")  # With v prefix
        self.assertEqual(v2.major, 1)
        self.assertEqual(v2.minor, 28)
        self.assertEqual(v2.patch, 0)
        
        v3 = Version("1.27")  # Without patch
        self.assertEqual(v3.major, 1)
        self.assertEqual(v3.minor, 27)
        self.assertEqual(v3.patch, 0)
    
    def test_version_comparison(self):
        """Test version comparison operators"""
        v1 = Version("1.27.4")
        v2 = Version("1.27.9")
        v3 = Version("1.28.0")
        
        self.assertTrue(v1 < v2)
        self.assertTrue(v2 < v3)
        self.assertTrue(v1 < v3)
        self.assertFalse(v3 < v1)
        
        self.assertTrue(v1 <= v2)
        self.assertTrue(v1 == Version("1.27.4"))
    
    def test_patch_upgrade_path(self):
        """Test patch version upgrade (no multi-step)"""
        current = Version("1.27.1")
        target = Version("1.27.9")
        
        path = calculate_upgrade_path(current, target)
        
        self.assertEqual(len(path), 1)
        self.assertEqual(str(path[0]), "1.27.9")
    
    def test_single_minor_upgrade_path(self):
        """Test single minor version upgrade (no multi-step)"""
        current = Version("1.27.4")
        target = Version("1.28.0")
        
        path = calculate_upgrade_path(current, target)
        
        self.assertEqual(len(path), 1)
        self.assertEqual(str(path[0]), "1.28.0")
    
    def test_multi_step_upgrade_path(self):
        """Test multi-step upgrade path calculation"""
        current = Version("1.25.0")
        target = Version("1.28.0")
        
        path = calculate_upgrade_path(current, target)
        
        self.assertEqual(len(path), 3)
        self.assertEqual(str(path[0]), "1.26.0")
        self.assertEqual(str(path[1]), "1.27.0")
        self.assertEqual(str(path[2]), "1.28.0")
    
    def test_large_version_jump(self):
        """Test large version jump requiring many steps"""
        current = Version("1.22.0")
        target = Version("1.27.0")
        
        path = calculate_upgrade_path(current, target)
        
        self.assertEqual(len(path), 5)
        self.assertEqual(str(path[0]), "1.23.0")
        self.assertEqual(str(path[1]), "1.24.0")
        self.assertEqual(str(path[2]), "1.25.0")
        self.assertEqual(str(path[3]), "1.26.0")
        self.assertEqual(str(path[4]), "1.27.0")
    
    def test_downgrade_prevention(self):
        """Test that downgrade is prevented"""
        current = Version("1.28.0")
        target = Version("1.27.0")
        
        path = calculate_upgrade_path(current, target)
        
        self.assertEqual(len(path), 0)  # Empty path for downgrade
    
    def test_same_version(self):
        """Test same version returns empty path"""
        current = Version("1.27.4")
        target = Version("1.27.4")
        
        path = calculate_upgrade_path(current, target)
        
        self.assertEqual(len(path), 0)
    
    def test_version_validation(self):
        """Test version string validation"""
        # Valid versions
        valid, msg = validate_version_string("1.27.4")
        self.assertTrue(valid)
        
        valid, msg = validate_version_string("1.28.0")
        self.assertTrue(valid)
        
        # Invalid versions
        valid, msg = validate_version_string("2.0.0")
        self.assertFalse(valid)
        self.assertIn("1.x", msg)
        
        valid, msg = validate_version_string("1.19.0")
        self.assertFalse(valid)
        self.assertIn("too old", msg)
        
        valid, msg = validate_version_string("invalid")
        self.assertFalse(valid)
    
    def test_upgrade_warnings(self):
        """Test upgrade warnings generation"""
        # No warnings for simple upgrade
        current = Version("1.27.0")
        target = Version("1.28.0")
        warnings = get_upgrade_warnings(current, target)
        self.assertEqual(len(warnings), 0)
        
        # Warning for large jump
        current = Version("1.23.0")
        target = Version("1.28.0")
        warnings = get_upgrade_warnings(current, target)
        self.assertGreater(len(warnings), 0)
        self.assertTrue(any("5 minor versions" in w for w in warnings))
        
        # Warning for 1.21 -> 1.22+ (API removals)
        current = Version("1.21.0")
        target = Version("1.22.0")
        warnings = get_upgrade_warnings(current, target)
        self.assertTrue(any("APIs have been removed" in w for w in warnings))
        
        # Warning for 1.24 -> 1.25+ (PSP removal)
        current = Version("1.24.0")
        target = Version("1.25.0")
        warnings = get_upgrade_warnings(current, target)
        self.assertTrue(any("PodSecurityPolicy" in w for w in warnings))
    
    def test_is_patch_upgrade(self):
        """Test patch upgrade detection"""
        self.assertTrue(is_patch_upgrade(
            Version("1.27.1"), 
            Version("1.27.9")
        ))
        
        self.assertFalse(is_patch_upgrade(
            Version("1.27.1"), 
            Version("1.28.0")
        ))
    
    def test_format_upgrade_path_message(self):
        """Test upgrade path message formatting"""
        # Single step
        path = [Version("1.28.0")]
        msg = format_upgrade_path_message(path)
        self.assertIn("Direct", msg)
        self.assertIn("1.28.0", msg)
        
        # Multi-step
        path = [Version("1.26.0"), Version("1.27.0"), Version("1.28.0")]
        msg = format_upgrade_path_message(path)
        self.assertIn("Multi-step", msg)
        self.assertIn("3 steps", msg)
        
        # Empty path
        msg = format_upgrade_path_message([])
        self.assertIn("No upgrade", msg)


if __name__ == '__main__':
    unittest.main()
