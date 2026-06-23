//! <one line: what this recovers/transforms and for which target>.
//!
//! WHY: explain the RE reasoning for a learner — what you observed in the binary and
//! why this reproduces it. std-only (no crates: the air-gapped image has no crates.io).
//!
//! Build & test:  rustc --test rust_template.rs -o /tmp/t && /tmp/t
//! Build & run:   rustc -O rust_template.rs -o /tmp/solve && /tmp/solve <input>

/// The deterministic core (parser / transform / keygen). Pure + side-effect-free so it
/// can be unit-tested with known input/output vectors. Replace the body.
fn solve(data: &[u8]) -> Vec<u8> {
    // why: placeholder identity transform — replace with the real logic.
    data.to_vec()
}

fn main() {
    let arg = std::env::args().nth(1).unwrap_or_default();
    println!("{}", String::from_utf8_lossy(&solve(arg.as_bytes())));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_vector() {
        // Replace with a known input/output vector recovered from the target.
        assert_eq!(solve(b"AB"), b"AB");
    }
}
