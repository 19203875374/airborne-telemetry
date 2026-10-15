#!/usr/bin/env python3
"""Synthetic regression fixtures only. No FPGA or RF measurements are used."""
import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT/'telemetry-evidence-review'/'scripts'
PYNQ = ROOT/'pynq-overlay-preflight'/'scripts'/'preflight_overlay.py'


class ScriptCases(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.p = Path(self.tmp.name)
        self.iq = self.p/'tone.csv'
        self.iq.write_text('sample,i,q,inc\n0,1,0,16384\n1,0,1,16384\n2,-1,0,16384\n3,0,-1,16384\n')

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, script, args, expected=0):
        r = subprocess.run([sys.executable, str(script), *map(str, args)],
                           capture_output=True, text=True, timeout=20)
        self.assertEqual(r.returncode, expected, r.stdout+r.stderr)
        return json.loads(r.stdout if r.stdout.strip() else r.stderr)

    def iq_run(self, *args, expected=0):
        return self.run_script(MAIN/'inspect_iq.py', [self.iq, '--fs', 4000000, *args], expected)

    def test_iq_known_quadrature_tone(self):
        x=self.iq_run('--sample','sample')
        self.assertAlmostEqual(x['papr_db'],0)
        self.assertAlmostEqual(x['phase_frequency_mean_hz'],1000000)

    def test_iq_does_not_bridge_gaps(self):
        self.iq.write_text('sample,i,q\n0,1,0\n1,0,1\n3,-1,0\n4,0,-1\n')
        x=self.iq_run('--sample','sample')
        self.assertEqual(x['sample_index_breaks'],1)
        self.assertEqual(x['phase_difference_pairs'],2)

    def test_iq_all_zero_is_undefined_papr(self):
        self.iq.write_text('i,q\n0,0\n0,0\n')
        self.assertIsNone(self.iq_run()['papr_db'])

    def test_iq_rejects_nan(self):
        self.iq.write_text('i,q\nnan,0\n')
        self.iq_run(expected=2)

    def test_iq_rejects_duplicate_index(self):
        self.iq.write_text('sample,i,q\n0,1,0\n0,0,1\n')
        self.iq_run('--sample','sample',expected=2)

    def test_iq_rejects_missing_columns(self):
        self.iq.write_text('one,two\n1,0\n')
        self.iq_run(expected=2)

    def test_iq_uses_separate_accumulator_rate(self):
        x=self.iq_run('--inc','inc','--inc-fs',16000000)
        self.assertEqual(x['inc_frequency_hz']['max'],4000000)

    def test_iq_does_not_guess_accumulator_rate(self):
        self.assertIsNone(self.iq_run('--inc','inc')['inc_frequency_hz'])

    def test_golden_identical(self):
        x=self.run_script(MAIN/'compare_golden.py',[self.iq,self.iq,'--columns','sample','i','q'])
        self.assertTrue(x['passed'])

    def test_golden_detects_wrong_sample(self):
        actual=self.p/'actual.csv';actual.write_text(self.iq.read_text().replace('2,-1,0','2,-0.5,0'))
        x=self.run_script(MAIN/'compare_golden.py',[self.iq,actual,'--columns','sample','i','q'],1)
        self.assertEqual(x['failures'],1)

    def test_golden_respects_explicit_tolerance(self):
        actual=self.p/'actual.csv';actual.write_text(self.iq.read_text().replace('2,-1,0','2,-0.99,0'))
        self.run_script(MAIN/'compare_golden.py',[self.iq,actual,'--columns','i','q','--atol','.02'])

    def test_golden_rejects_short_capture(self):
        actual=self.p/'actual.csv';actual.write_text('sample,i,q,inc\n0,1,0,16384\n')
        self.run_script(MAIN/'compare_golden.py',[self.iq,actual,'--columns','i','q'],2)

    def test_golden_rejects_nonfinite(self):
        actual=self.p/'actual.csv';actual.write_text('i,q\nnan,0\n')
        self.run_script(MAIN/'compare_golden.py',[self.iq,actual,'--columns','i','q'],2)

    def record(self):
        self.manifest=self.p/'release.json'
        self.run_script(MAIN/'release_manifest.py',['record','--root',self.p,'--files','tone.csv','--manifest',self.manifest])

    def verify(self, expected=0):
        return self.run_script(MAIN/'release_manifest.py',['verify','--root',self.p,'--manifest',self.manifest],expected)

    def test_manifest_roundtrip(self):
        self.record();self.assertTrue(self.verify()['passed'])

    def test_manifest_detects_byte_mutation(self):
        self.record();self.iq.write_text(self.iq.read_text()+'\n')
        self.assertFalse(self.verify(1)['passed'])

    def test_manifest_detects_missing_dependency(self):
        self.record();self.iq.unlink();self.verify(1)

    def test_manifest_rejects_escape(self):
        self.run_script(MAIN/'release_manifest.py',['record','--root',self.p,'--files','../outside','--manifest',self.p/'m.json'],2)

    def overlay(self, xml='<ROOT><MODULE FULLNAME="/core_0"/></ROOT>'):
        # Deliberately not a usable bitstream; tests file-check behavior only.
        self.bit=self.p/'design.bit';self.bit.write_bytes(b'SYNTHETIC-NOT-FOR-DOWNLOAD')
        self.hwh=self.p/'design.hwh';self.hwh.write_text(xml)

    def preflight(self,*args,expected=0):
        return self.run_script(PYNQ,['--bit',self.bit,'--hwh',self.hwh,*args],expected)

    def test_pynq_static_checks_never_claim_hardware(self):
        self.overlay();x=self.preflight('--require-ip','core_0')
        self.assertTrue(x['static_checks_passed']);self.assertFalse(x['hardware_validated'])

    def test_pynq_detects_missing_ip(self):
        self.overlay();self.preflight('--require-ip','missing',expected=1)

    def test_pynq_accepts_copied_fullname(self):
        self.overlay('<ROOT><MODULE FULLNAME="/dsp/filter_0"/></ROOT>')
        self.preflight('--require-ip','/dsp/filter_0')

    def test_pynq_rejects_mismatched_names(self):
        self.overlay();other=self.p/'wrong.hwh';self.hwh.rename(other);self.hwh=other
        self.preflight(expected=2)

    def test_pynq_rejects_malformed_xml(self):
        self.overlay('<ROOT>');self.preflight(expected=2)

    def test_pynq_supports_xml_namespace(self):
        self.overlay('<r:ROOT xmlns:r="urn:example"><r:MODULE INSTANCE="core_0"/></r:ROOT>')
        self.preflight('--require-ip','core_0')

    def test_pynq_rejects_unknown_schema(self):
        self.overlay('<ROOT/>');self.preflight(expected=2)

    def test_pynq_rejects_entity_declaration(self):
        self.overlay('<!DOCTYPE ROOT [<!ENTITY x "value">]><ROOT/>');self.preflight(expected=2)


if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(ScriptCases)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    report={'scope':'synthetic software regression only; no hardware',
            'tests_run':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),
            'passed':result.wasSuccessful(),'python':sys.version.split()[0],
            'test_names':sorted(x for x in dir(ScriptCases) if x.startswith('test_'))}
    (Path(__file__).parent/'test_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    sys.exit(0 if result.wasSuccessful() else 1)
