int convertToBaseUnit({
  required int inputQty,
  required String? inputUnit,
  required String? unitIn,
  required String? unitOut,
  required double rate,
}) {
  if (inputUnit == null) return inputQty;

  // unitIn → 변환 필요
  if (inputUnit == unitIn) {
    return (inputQty * rate).round();
  }

  // unitOut → 그대로
  return inputQty;
}