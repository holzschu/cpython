import numpy as np
import scipy
from scipy import (
    integrate,
    interpolate,
    io,
    linalg,
    odr,
    optimize,
    signal,
    special,
    stats,
)
from scipy.optimize.cython_optimize import _zeros
from scipy.sparse.linalg import svds

assert np.__version__ == "2.3.1"
np.testing.assert_allclose(np.linalg.solve([[3.0, 1.0], [1.0, 2.0]], [9.0, 8.0]), [2.0, 3.0])
np.testing.assert_allclose(np.linalg.eigvalsh([[2.0, 1.0], [1.0, 2.0]]), [1.0, 3.0])
np.testing.assert_allclose(np.linalg.cholesky([[4.0, 2.0], [2.0, 5.0]]), [[2.0, 0.0], [1.0, 2.0]])
np.testing.assert_allclose(np.linalg.svd([[2.0, 1.0], [1.0, 2.0]], compute_uv=False), [3.0, 1.0])
print("NumPy solve, eigenvalues, Cholesky and SVD PASS", flush=True)

assert scipy.__version__ == "1.16.1"
np.testing.assert_allclose(linalg.solve([[3.0, 1.0], [1.0, 2.0]], [9.0, 8.0]), [2.0, 3.0])
np.testing.assert_allclose(special.gamma([1.0, 2.0, 3.0, 4.0]), [1.0, 1.0, 2.0, 6.0])
np.testing.assert_allclose(integrate.quad(lambda x: x * x, 0.0, 1.0)[0], 1.0 / 3.0)
np.testing.assert_allclose(interpolate.CubicSpline([0.0, 1.0, 2.0], [0.0, 1.0, 4.0])(0.5), 0.25)
for dtype in (np.float32, np.float64, np.complex64, np.complex128):
    np.testing.assert_allclose(svds(np.diag(np.array([3.0, 1.0], dtype=dtype)), k=1, solver="propack", return_singular_vectors=False), [3.0], rtol=1e-5)
np.testing.assert_allclose(svds(np.diag([3.0, 1.0]), k=1, solver="arpack", v0=[1.0, 1.0], return_singular_vectors=False), [3.0])
for method in ("vode", "dopri5", "dop853"):
    solver = integrate.ode(lambda t, y: -y).set_integrator(method)
    solver.set_initial_value([1.0], 0.0)
    np.testing.assert_allclose(solver.integrate(0.1), [0.9048374180359595], rtol=1e-5)
    assert solver.successful()
np.testing.assert_allclose(integrate.odeint(lambda y, t: -y, [1.0], [0.0, 0.1])[-1], [0.9048374180359595], rtol=1e-5)
np.testing.assert_allclose(interpolate.splev(0.5, interpolate.splrep([0.0, 1.0, 2.0, 3.0], [0.0, 1.0, 4.0, 9.0])), 0.25)
fit = odr.ODR(odr.Data([0.0, 1.0, 2.0], [1.0, 3.0, 5.0]), odr.Model(lambda beta, x: beta[0] * x + beta[1]), beta0=[1.0, 0.0]).run()
np.testing.assert_allclose(fit.beta, [2.0, 1.0], rtol=1e-5)
print("SciPy LAPACK, special functions, quadrature, spline and four PROPACK types PASS", flush=True)
np.testing.assert_allclose(stats.norm.cdf(0.0), 0.5)
np.testing.assert_allclose(optimize.brentq(lambda x: x * x - 2.0, 0.0, 2.0), np.sqrt(2.0))
np.testing.assert_allclose(signal.convolve([1, 2], [1, 1]), [1, 3, 2])
assert "brentq" in _zeros.__pyx_capi__
assert callable(io.mmread) and callable(odr.ODR)
print("SciPy statistics, optimization, signal, IO and ODR imports PASS", flush=True)
