from godot import exposed, export
from godot.bindings import Node
import numpy as np

@exposed
class TestPython(Node):
	def _ready(self):
		arr = np.array([1, 2, 3])
		print(f"Numpy Array: {arr}")
