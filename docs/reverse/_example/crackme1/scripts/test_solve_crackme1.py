from solve_crackme1 import keygen


def test_known_vector():
    assert keygen("AB") == "BC"  # 'A'+1='B', 'B'+1='C'
