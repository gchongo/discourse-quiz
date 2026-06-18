import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class QuizInfoButton extends Component {
  @service site;

  get shouldHideLabelOnMobile() {
    return this.args.hideLabelOnMobile !== false;
  }

  get labelKey() {
    if (this.site.mobileView && this.shouldHideLabelOnMobile) {
      return null;
    }

    return this.args.labelKey;
  }

  get titleKey() {
    if (this.site.mobileView && this.shouldHideLabelOnMobile) {
      return this.args.labelKey;
    }

    return this.args.titleKey;
  }

  get ariaLabelKey() {
    return this.args.ariaLabelKey || this.args.labelKey;
  }

  <template>
    <DButton
      @action={{@action}}
      @icon={{or @icon "circle-info"}}
      @label={{this.labelKey}}
      @title={{this.titleKey}}
      @ariaLabel={{this.ariaLabelKey}}
      class={{dConcatClass "btn-icon-text" "-ghost" "quiz-info-ghost-btn" @className}}
    />
  </template>
}
