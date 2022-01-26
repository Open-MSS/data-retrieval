import os
import glob

import xarray


def test_get_cds(tmpdir):
    base = os.path.dirname(__file__) + "/../"

    with open(base + "_test/configs/settings.config") as tf:
        config = tf.read().format(tmpdir=str(tmpdir), bindir=base + "bin")
    with open(base + "settings.config", "w") as tf:
        tf.write(config)
    os.symlink(base + "_test/grib", tmpdir / "grib")
    os.symlink(base + "_test/mss", tmpdir / "mss.ref")
    os.chdir(base)
    os.system("bash bin/get_cds.sh 2021-01-29 00:00:00")

    os.chdir(tmpdir)
    for ref_fn in glob.glob("mss.ref/*nc"):
        fut_fn = ref_fn.replace(".ref", "")
        print("Checking", fut_fn)
        assert os.path.exists(fut_fn)

        with xarray.load_dataset(ref_fn) as ref, \
                xarray.load_dataset(fut_fn) as fut:
            for var in ref.variables:
                print("   Checking", var)
                assert var in fut.variables
                for att in ["units", "standard_name"]:
                    if att in ref[var].attrs:
                        assert att in fut[var].attrs
                        assert ref[var].attrs[att] == fut[var].attrs[att]
