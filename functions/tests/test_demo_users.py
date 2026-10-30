"""demo_users.py: which uids count on the real project, under the emulator and on a `demo-*`
project. Every uid is invented."""

import pytest

import demo_users


def on_the_real_project(monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", "ronda-uy")
    monkeypatch.delenv("FUNCTIONS_EMULATOR", raising=False)


def under_the_emulator(monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", "ronda-uy")
    monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")


def on_a_demo_project(monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", "demo-ronda")
    monkeypatch.delenv("FUNCTIONS_EMULATOR", raising=False)


@pytest.mark.parametrize("uid", ["demo-001", "demo-host", "demo-"])
def test_a_uid_starting_with_demo_dash_is_invented(uid):
    assert demo_users.is_demo_uid(uid)


@pytest.mark.parametrize("uid", ["Xb3kQ9", "demo", "Demo-001", "my-demo-001", "", None])
def test_any_other_uid_is_not(uid):
    assert not demo_users.is_demo_uid(uid)


class TestOnTheRealProject:
    @pytest.fixture(autouse=True)
    def real(self, monkeypatch):
        on_the_real_project(monkeypatch)

    def test_demo_sign_ups_do_not_count(self):
        assert not demo_users.demo_counts_here()
        assert not demo_users.counts("demo-001")

    def test_real_members_do(self):
        assert demo_users.counts("Xb3kQ9")

    def test_a_project_named_demo_further_in_is_still_real(self, monkeypatch):
        monkeypatch.setenv("GCLOUD_PROJECT", "ronda-demo")

        assert not demo_users.counts("demo-001")

    def test_without_a_project_id_it_counts_as_real(self, monkeypatch):
        monkeypatch.delenv("GCLOUD_PROJECT")

        assert not demo_users.counts("demo-001")

    def test_only_true_turns_the_emulator_on(self, monkeypatch):
        monkeypatch.setenv("FUNCTIONS_EMULATOR", "false")

        assert not demo_users.counts("demo-001")


@pytest.mark.parametrize("where", [under_the_emulator, on_a_demo_project])
def test_under_the_emulator_and_on_a_demo_project_everyone_counts(monkeypatch, where):
    where(monkeypatch)

    assert demo_users.demo_counts_here()
    assert demo_users.counts("demo-001")
    assert demo_users.counts("Xb3kQ9")
