import React, { Component } from "react";
import ReactDOM from "react-dom";
import SketchPicker from "react-color/src/components/sketch/Sketch";
import tinycolor from "tinycolor2";

function toState(input) {
  const color = tinycolor(input);

  return {
    format: color.getFormat() || "hex",
    color: color.toRgb()
  };
}

export default class ColorPicker extends Component {
  state = toState(window.selectedColor);

  componentDidMount() {
    Object.defineProperty(window, "selectedColor", {
      get: () => {
        const color = tinycolor(this.state.color);

        switch (this.state.format) {
          case "hsl":
            return color.toHslString();
          case "hex8":
            return color.toHex8String();
          case "prgb":
            return color.toPercentageRgbString();
          case "rgb":
            return color.toRgbString();
          default:
            return color.getAlpha() === 1
              ? color.toHexString()
              : color.toRgbString();
        }
      },
      set: color => this.setState(toState(color))
    });
  }

  setColor = color => this.setState({ color: color.rgb });

  render() {
    return (
      <SketchPicker
        className="picker"
        width={300}
        presetColors={[]}
        color={this.state.color}
        onChangeComplete={this.setColor}
      />
    );
  }
}

ReactDOM.render(<ColorPicker />, document.getElementById("root"));
